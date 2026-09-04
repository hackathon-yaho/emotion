FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle
# Windows에서 만든 저장소는 gradlew에 실행 비트가 없다. git 쪽도 +x로 올려뒀지만,
# 누가 Windows에서 다시 추가하면 또 사라지므로 여기서 한 번 더 세운다 —
# 안 하면 리눅스 빌드가 "permission denied"로 죽고, 그건 배포 당일에 발견된다.
RUN chmod +x gradlew && ./gradlew --version
COPY src ./src
RUN ./gradlew bootJar --no-daemon -x test

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
