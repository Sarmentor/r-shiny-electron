FROM ubuntu:trusty-20190122 as rbuild

ENV DEBIAN_FRONTEND=noninteractive DOCKER_BUILD=1

WORKDIR /workspace

RUN echo 'deb http://cran.rstudio.com/bin/linux/ubuntu trusty-cran35/' >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
 && apt-get update \
 && URLS=$(apt-get install -y --no-install-recommends --print-uris \
       r-base=3.5.3-1trusty \
       r-recommended=3.5.3-1trusty \
       r-base-core=3.5.3-1trusty \
       r-cran-codetools=0.2-15-1.1trusty0 \
       r-cran-cluster=2.0.7-1-1trusty0 \
       r-cran-foreign=0.8.59-1 \
       r-cran-kernsmooth=2.23-10-2 \
       r-cran-mass=7.3-29-1 \
       r-cran-mgcv=1.7-28-1 \
       r-cran-nlme=3.1.113-1 \
       r-cran-rpart=4.1-5-1 \
       r-cran-survival=2.37-7-1 \
       r-cran-matrix=1.1-2-1 \
    | cut -d "'" -f 2 | grep -e "^http") \
 && apt-get install -y --no-install-recommends wget \
 && echo "$URLS" | wget -c -i- \
 && mkdir -p ./r-linux/ \
 && cd ./r-linux/ \
 && mkdir -p usr/bin usr/lib \
 && find ../*.deb -exec dpkg-deb -X {} . \; \
 && sed -i 's/R_HOME_DIR=\/usr\/lib\/R/#R_HOME_DIR=\/usr\/lib\/R/' ./usr/lib/R/bin/R \
 && mv ./etc/R/* ./usr/lib/R/etc/ \
 && cd /workspace \
 && mv r-linux / \
 && cp /lib/x86_64-linux-gnu/libreadline.so.6 /r-linux/usr/lib/x86_64-linux-gnu/ \
 && cp /lib/x86_64-linux-gnu/libtinfo.so.5 /r-linux/usr/lib/x86_64-linux-gnu/ \
 && cp /lib/x86_64-linux-gnu/libpcre.so.3 /r-linux/usr/lib/x86_64-linux-gnu/ \
 && cp /lib/x86_64-linux-gnu/libbz2.so.1.0 /r-linux/usr/lib/x86_64-linux-gnu/ \
 && cp /lib/x86_64-linux-gnu/libpng12.so.0 /r-linux/usr/lib/x86_64-linux-gnu/ \
 && find /r-linux/lib/x86_64-linux-gnu/ -regex "^.*\.so\.[0-9]+$" -exec cp {} /r-linux/usr/lib/x86_64-linux-gnu/ \; \
 && rm -rf /r-linux/lib \
 && rm -rf /r-linux/usr/bin /r-linux/usr/include /r-linux/usr/sbin \
 && find /r-linux/usr/share/* -maxdepth 0 ! -name "fonts" -exec rm -rf {} + \
 && find /r-linux/etc/* -maxdepth 0 ! -name "fonts" -exec rm -rf {} + \
 && mv /r-linux/etc/fonts /r-linux/usr/lib/R/etc/ \
 && rmdir /r-linux/etc \
 && mv /r-linux/usr/share/fonts /r-linux/usr/lib/R/ \
 && rmdir /r-linux/usr/share/ \
 && rm -f /r-linux/usr/lib/libR.so \
 && find /r-linux/usr/lib/* -maxdepth 0 ! -name "R" -exec mv {} /r-linux/usr/lib/R/lib/ \; \
 && cp -r /r-linux/usr/lib/R/bin/exec/* /r-linux/usr/lib/R/bin/ \
 && rm -rf /r-linux/usr/lib/R/bin/exec/ \
 && mv /r-linux/usr/lib/R /r-linux.temp \
 && rm -rf /r-linux \
 && mv /r-linux.temp /r-linux

RUN apt-get install -y --no-install-recommends \
       build-essential \
       libcurl4-openssl-dev \
       r-base=3.5.3-1trusty \
       r-recommended=3.5.3-1trusty \
       r-base-core=3.5.3-1trusty \
       r-cran-codetools=0.2-15-1.1trusty0 \
       r-cran-cluster=2.0.7-1-1trusty0 r-cran-foreign=0.8.59-1 r-cran-kernsmooth=2.23-10-2 r-cran-mass=7.3-29-1 r-cran-mgcv=1.7-28-1 r-cran-nlme=3.1.113-1 r-cran-rpart=4.1-5-1 r-cran-survival=2.37-7-1 r-cran-matrix=1.1-2-1

WORKDIR /

COPY add-cran-binary-pkgs.R ./
RUN Rscript /add-cran-binary-pkgs.R

COPY requirements.txt ./
RUN Rscript /add-cran-binary-pkgs.R requirements.txt


#####################################################################################################################


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
       && cmake .. && make && make install && cd ../.. && rm -rf innoextract-1.7 innoextract-1.7.tar.gz

WORKDIR /workdir

COPY get-r-win.sh get-r-mac.sh ./
RUN ./get-r-win.sh && ./get-r-mac.sh

COPY add-cran-binary-pkgs.R /
RUN Rscript /add-cran-binary-pkgs.R

COPY requirements.txt ./
RUN Rscript /add-cran-binary-pkgs.R requirements.txt

COPY --from=rbuild /r-linux/ ./r-linux/

# Remove BH, which is a very large library and seems unnecessary
RUN rm -rf {r-win,r-mac,r-linux}/library/BH

COPY package.json package-lock.json ./

RUN npm install

COPY . ./

CMD ["npm", "run", "dist", "--", "-wml"]
