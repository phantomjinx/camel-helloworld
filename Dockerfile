FROM maven:3-eclipse-temurin-17

WORKDIR /camel-helloworld

ADD src src
ADD pom.xml pom.xml
ADD jmx-exporter.yml jmx-exporter.yml
ADD start-jar.sh start-jar.sh

RUN mvn clean package

RUN chmod 755 start-jar.sh

EXPOSE 10000
EXPOSE 10001

ENTRYPOINT ["sh", "./start-jar.sh"]
