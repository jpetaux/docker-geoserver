FROM openjdk:8-jre
LABEL maintainer "Mikko Rauhala <mikko@meteo.fi>"

# persistent / runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends libnetcdfc++4 && rm -r /var/lib/apt/lists/*

ENV GEOSERVER_VERSION 2.10.2
ENV GEOSERVER_PLUGINS css grib netcdf pyramid wps ysld
ENV GEOSERVER_HOME /usr/share/geoserver
#ENV GEOSERVER_DATA_DIR /data/geoserver
ENV JAVA_OPTS -Xbootclasspath/a:${JAVA_HOME}/jre/lib/ext/marlin-0.7.4-Unsafe.jar -Xbootclasspath/p:${JAVA_HOME}/jre/lib/ext/marlin-0.7.4-Unsafe-sun-java2d.jar -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine -XX:+UseG1GC

# Install native JAI, ImageIO and Marlin Renderer
RUN \
    cd $JAVA_HOME && \
    wget -nv http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64-jre.bin && \
    echo "yes" | sh jai-1_1_3-lib-linux-amd64-jre.bin && \
    rm jai-1_1_3-lib-linux-amd64-jre.bin && \
    # ImageIO
    cd $JAVA_HOME && \
    export _POSIX2_VERSION=199209 &&\
    wget -nv http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64-jre.bin && \
    echo "yes" | sh jai_imageio-1_1-lib-linux-amd64-jre.bin && \
    rm jai_imageio-1_1-lib-linux-amd64-jre.bin && \
    # Get Marlin Renderer
    cd $JAVA_HOME/lib/ext/ && \
    wget -nv https://github.com/bourgesl/marlin-renderer/releases/download/v0.7.4_2/marlin-0.7.4-Unsafe.jar && \
    wget -nv https://github.com/bourgesl/marlin-renderer/releases/download/v0.7.4_2/marlin-0.7.4-Unsafe-sun-java2d.jar

#
# GEOSERVER INSTALLATION
#

# Install GeoServer
RUN wget -nv http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/geoserver-$GEOSERVER_VERSION-bin.zip && \
    unzip geoserver-$GEOSERVER_VERSION-bin.zip -d /usr/share && mv -v /usr/share/geoserver* $GEOSERVER_HOME && \
    rm geoserver-$GEOSERVER_VERSION-bin.zip && \
    sed -e 's/>PARTIAL-BUFFER2</>SPEED</g' -i $GEOSERVER_HOME/webapps/geoserver/WEB-INF/web.xml && \
    # Remove old JAI from geoserver
    rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_codec-*.jar && \
    rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_core-*jar && \
    rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_imageio-*.jar

# Install GeoServer Plugins
RUN for PLUGIN in ${GEOSERVER_PLUGINS}; \
    do \
      wget -nv http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip && \
      unzip -o geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip -d /usr/share/geoserver/webapps/geoserver/WEB-INF/lib/ && \
      rm geoserver-$GEOSERVER_VERSION-$PLUGIN-plugin.zip ; \
    done

# Expose GeoServer's default port
EXPOSE 8080

HEALTHCHECK --interval=5m --timeout=3s \
    CMD curl -f "http://localhost:8080/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities" || exit 1

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["geoserver"]

