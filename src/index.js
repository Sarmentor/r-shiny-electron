import { app, session, BrowserWindow } from 'electron'

import path from 'path'
import url from 'url'
import http from 'axios'
import os from 'os'
import execa from 'execa'
import { randomPort, waitFor, getRPath } from './helpers'

const isDevelopment = process.env.NODE_ENV !== 'production'

const rDir = getRPath(os.platform())
const basePath = isDevelopment ? __dirname : app.getAppPath();
const appPath = path.join(basePath, '..');

// signal if a shutdown of the app was requested
// this is used to prevent an error window once the R session dies
let shutdown = false

const rPath = path.resolve(path.join(appPath, rDir))
const libPath = path.join(rPath, 'library')
const rscript = path.join(rPath, 'bin', 'R')
const shinyAppPath = path.join(appPath, 'shiny')

const backgroundColor = '#2c3e50'

// We have to launch a child process for the R shiny webserver
// Things we need to take into account:
// The process dies during setup
// The process dies during app usuage (e.g. the OS kills the process)
// At the random port, another webserver is running
// at any given time there should be 0 or 1 shiny processes
let rShinyProcess = null

// tries to start a webserver
// attempt - a counter how often it was attempted to start a webserver
// use the progress call back to listen for intermediate status reports
// use the onErrorStartup callback to react to a critical failure during startup
// use the onErrorLater callback to handle the case when the R process dies
// use onSuccess to retrieve the shinyUrl
const tryStartWebserver = async (attempt, progressCallback, onErrorStartup,
  onErrorLater, onSuccess) => {
  if (attempt > 3) {
    await progressCallback({attempt: attempt, code: 'failed'})
    await onErrorStartup()
    return
  }

  if (rShinyProcess !== null) {
    await onErrorStartup() // should not happen
    return
  }

  let shinyPort = randomPort()

  console.log(`Shiny port: ${shinyPort}`)

  await progressCallback({attempt: attempt, code: 'start'})

  let shinyRunning = false
  const onError = async (e) => {
    console.error(e)
    rShinyProcess = null
    if (shutdown) { // global state :(
      return
    }
    if (shinyRunning) {
      await onErrorLater()
    } else {
      await tryStartWebserver(attempt + 1, progressCallback, onErrorStartup, onErrorLater, onSuccess)
    }
  }

  let shinyProcessAlreadyDead = false

  let extraEnv = {}
  if (os.platform() == 'linux') {
    extraEnv = {
      'LD_LIBRARY_PATH': `${rPath}/lib/:${rPath}/lib/libblas/:${rPath}/lib/lapack/:${rPath}/lib/x86_64-linux-gnu/`,
      'EDITOR': 'vi',
      'FONTCONFIG_PATH': path.join(rPath, 'etc', 'fonts'),
      'XDG_DATA_HOME': rPath,
    }
  }
  rShinyProcess = execa(rscript,
    ['--vanilla', '-f', path.join(appPath, 'start-shiny.R')],
    { env: {
      ...extraEnv,
      'WITHIN_ELECTRON': '1', // can be used within an app to implement specific behaviour
      'R_HOME': rPath,
      'R_HOME_DIR': rPath,
      'RE_SHINY_PORT': shinyPort,
      'RE_SHINY_PATH': shinyAppPath,
      'R_LIBS': libPath,
      'R_LIBS_USER': libPath,
      'R_LIBS_SITE': libPath,
      'R_LIB_PATHS': libPath} }).catch((e) => {
        shinyProcessAlreadyDead = true
        onError(e)
      })

  let url = `http://127.0.0.1:${shinyPort}`
  for (let i = 0; i <= 10; i++) {
    if (shinyProcessAlreadyDead) {
      break
    }
    await waitFor(500)
    try {
      const res = await http.head(url, {timeout: 1000})
      // TODO: check that it is really shiny and not some other webserver
      if (res.status === 200) {
        await progressCallback({attempt: attempt, code: 'success'})
        shinyRunning = true
        onSuccess(url)
        return
      }
    } catch (e) {

    }
  }
  await progressCallback({attempt: attempt, code: 'notresponding'})

  try {
    rShinyProcess.kill()
  } catch (e) {}
}

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow

const windowOptions = {
  width: 800,
  height: 600,
  backgroundColor: backgroundColor,
  webPreferences: {
    nodeIntegration: false,
    contextIsolation: true
  }
}

const createWindow = (shinyUrl) => {
  mainWindow = new BrowserWindow(windowOptions)
  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

const createSplashScreen = (filename) => {
  console.log(__static)
  mainWindow.loadURL(url.format({
    pathname: path.join(__static, `${filename}.html`),
    protocol: 'file',
    slashes: true
  }))
}

const createLoadingSplashScreen = () => {
  createSplashScreen('loading')
}

const createErrorScreen = () => {
  createSplashScreen('failed')
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', async () => {
  // Set a content security policy
  session.defaultSession.webRequest.onHeadersReceived((_, callback) => {
    callback({
      responseHeaders: `
        default-src 'none';
        script-src 'self';
        img-src 'self' data:;
        style-src 'self';
        font-src 'self';
      `})
  })

  // Deny all permission requests
  session.defaultSession.setPermissionRequestHandler((_1, _2, callback) => {
    callback(false)
  })

  createWindow();
  createLoadingSplashScreen()
  await mainWindow.show();

  const emitSpashEvent = async (event, data) => {
    try {
      await mainWindow.webContents.send(event, data)
    } catch (e) {}
  }

  // pass the loading events down to the window
  const progressCallback = async (event) => {
    await emitSpashEvent('start-webserver-event', event)
  }

  const onErrorLater = async () => {
    if (!mainWindow) { // fired when we quit the app
      return
    }
    createErrorScreen()
  }

  const onErrorStartup = async () => {
    await waitFor(1000) // TODO: hack, only emit if the loading screen is ready
    await emitSpashEvent('failed')
  }

  try {
    await tryStartWebserver(0, progressCallback, onErrorStartup, onErrorLater, (url) => {
      mainWindow.loadURL(url)
    })
  } catch (e) {
    await emitSpashEvent('failed')
  }
})

// Quit when all windows are closed.
app.on('window-all-closed', () => {
  // On OS X it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  // if (process.platform !== 'darwin') {
  // }
  // We overwrite the behaviour for now as it makes things easier
  // remove all events
  shutdown = true
  app.quit()

  // kill the process, just in case
  // usually happens automatically if the main process is killed
  try {
    rShinyProcess.kill()
  } catch (e) {}
})

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  //if (mainWindow === null) {
  //  createWindow()
  //}
  // Deactivated for now
})
