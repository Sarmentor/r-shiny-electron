#!/usr/bin/env Rscript

# Script to find dependencies of a pkg list, download binaries and put them
# In the standalone R library.
args = commandArgs(trailingOnly=TRUE)

options(repos = "https://cloud.r-project.org")

cran_pkgs <- c("shiny")

if (length(args) == 1) {
  cat("Installing dependencies from file\n")
  cran_pkgs <- unique(scan(args[1], what="", sep="\n"))
} else if (length(args) > 1) {
  stop("Invalid number of arguments supplied (input file).n", call.=FALSE)
}

install_bins <- function(cran_pkgs, library_path, type, decompress = NULL,
                         remove_dirs = c("help", "doc", "tests", "html",
                                         "include", "unitTests",
                                         file.path("libs", "*dSYM"))) {
  
  installed <- list.files(library_path)
  cran_to_install <- sort(setdiff(
    unique(unlist(
      c(cran_pkgs,
        tools::package_dependencies(cran_pkgs, recursive=TRUE,
                                    which= c("Depends", "Imports", "LinkingTo"))))),
    installed))
  if(!length(cran_to_install)) {
    message("No packages to install")
  } else if (type == "source") {
    withCallingHandlers(install.packages(cran_to_install, lib=library_path, type="source"),
                        warning = function(w) stop(w))
  } else {
    td <- tempdir()
    downloaded <- download.packages(cran_to_install, destdir = td, type=type)
    apply(downloaded, 1, function(x) decompress(x[2], exdir = library_path))
    unlink(downloaded[,2])
  }
  # Only cleanup when a requirements file is provided as argument,
  # as some of these files can be necessary when installing other dependencies
  if (length(args) > 1) {
    z <- lapply(list.dirs(library_path, full.names = TRUE, recursive = FALSE),
                function(x) {
                  unlink(file.path(x, remove_dirs), force=TRUE, recursive=TRUE)
                })
  }
  invisible(NULL)
}

if (dir.exists("r-mac")) {
  install_bins(cran_pkgs = cran_pkgs, library_path = file.path("r-mac", "library"),
               type = "mac.binary.el-capitan", decompress = untar)
}

if (dir.exists("r-win")) {
  install_bins(cran_pkgs = cran_pkgs, library_path = file.path("r-win", "library"),
               type = "win.binary", decompress = unzip)
}

if (dir.exists("r-linux")) {
  install_bins(cran_pkgs = cran_pkgs, library_path = file.path("r-linux", "library"),
               type = "source")
}