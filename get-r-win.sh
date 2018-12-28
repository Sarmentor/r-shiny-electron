# Download and extract the Windows binary install
# Requires innoextract installed in the Dockerfile
mkdir r-win
curl -o r-win/R-win.exe https://cloud.r-project.org/bin/windows/base/old/3.5.1/R-3.5.1-win.exe
cd r-win
innoextract -e R-win.exe
mv app/* ../r-win
rm -r app R-win.exe

# Remove unneccessary files TODO: What else?
rm -r doc tests
