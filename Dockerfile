FROM rocker/shiny:3.5.1

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
       curl \
       gnupg2 \
       wget \
       cpio \
       libxml2-dev \
       libssl1.0-dev \
       build-essential \
       cmake \
       git \
       software-properties-common \
       dirmngr \
       curl \
       wget \
       cpio \
       gnupg2 \
       libxml2-dev \
       libssl1.0-dev \
       libboost-all-dev \
       liblzma-dev \
       git \
       software-properties-common \
       dirmngr \
       wine \
       wine32 \
       wine64 \
       libwine \
       libwine:i386 \
 && curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash - \
       && apt-get install -y --no-install-recommends nodejs \
 && apt-get autoremove -y \
 && apt-get clean \
 && wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/xar/xar-1.5.2.tar.gz \
       && tar -zxvf xar-1.5.2.tar.gz \
       && cd xar-1.5.2 && ./configure && make && make install \
       && cd .. && rm -rf xar-1.5.2 xar-1.5.2.tar.gz \
 && wget https://github.com/dscharrer/innoextract/releases/download/1.7/innoextract-1.7.tar.gz \
       && tar -xvzf innoextract-1.7.tar.gz \
       && mkdir -p innoextract-1.7/build && cd innoextract-1.7/build \
       && cmake .. && make && make install && cd ../.. && rm -rf innoextract-1.7 innoextract-1.7.tar.gz \
 && install2.r automagic \
       && rm -rf /tmp/downloaded_packages

WORKDIR /workdir

COPY get-r-win.sh get-r-mac.sh ./
RUN ./get-r-win.sh && ./get-r-mac.sh

COPY add-cran-binary-pkgs.R ./
RUN Rscript add-cran-binary-pkgs.R

COPY package.json package-lock.json ./

RUN npm install

COPY . ./

CMD ["npm", "run", "dist", "--", "-wml"]
