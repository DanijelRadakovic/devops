#import "lib.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#show: slides.with(
  title: "Docker - Najbolje Prakse",
  authors: ("Danijel Radaković"),
  ratio: 16/9,
  layout: "small",
  toc: false,
  count: "number",
  footer: false,
)

#set raw(theme: "goldfish.tmTheme")
#set figure(supplement: [Slika])

= Docker Build

== Docker Build - Bezbednosne preporuke

- *Multi-stage build* može drastično da smanji veličinu slike i da doprinosi povećanju bezbednosti.

- Povećanje bezbednosti pomoću _multi-stage build_-a: kreirati sliku koja se koristi samo za izvršavanje aplikacije u kojoj nema _source code_ fajlova kao i _build_ alata. Ovim se sprecava da neko u kontjejneru izmeni source code, _build_-uje izmenjenu (maliciouznu) verziju i pokrene.

- Povodom ovog pitanja jezici koji se kompajliraju imaju prednost (Go, Rust, C++) jer se pokreću kao izvršive datoteke (_binary_) u odnosu na interpretirane jezike (JavaScript, Python) jer zahtevaju source code da bi se pokrenuli.


== Docker Build - Bezbednosne preporuke

- Zbog toga je neophodno nezavisno od jezika da se _owner_ aplikacije podesi kao *root* user (`chmod`), kreirati novog korisnika u kontejneru koji će imati permisije da čita i izvršava aplikaciju (nema _write_ permisiju).

- U slučaju kompajliranih jezika neophodno je izmeniti permisije izvršive datoteke, dok kod interpretiranih jezika neophodno je izmeniti sve _source code_ fajlove i njihove zavisnosti.

- Preporučuje se da se koristi *slim* verzije docker slika jer pružaju manje prostora da se neka ranjivost pronađe u zavisnostima. (Primer iz _snyk_ softvera, broj zavisnosti je pao sa 544 na 55).

== Docker Build - Bezbednosne preporuke

#figure(image("figures/01.png"), caption: [Slim verzije slika imaju manje zavisnosti])

== Docker Build - Bezbednosne preporuke

- Koristiti #link("https://github.com/hadolint/hadolint")[hadolint] koji uočava sve propuste i nedostatke u Dockerfile-u.

- Neki od primera je _shell_ ili _exec_ varijante: #link("https://docs.docker.com/engine/reference/builder/#cmd")[CMD] i #link("https://docs.docker.com/engine/reference/builder/#entrypoint")[ENTRYPOINT].
  - _shell_ varijanta se ne koristi za pokretanje aplikacija jer ne prosleđuje signale podprocesima.

== Docker Build - Bezbednosne preporuke

- Korististi *clean build context*: koristiti poseban folder u kojem se nalaze svi neophodni fajlovi koji treba da budu deo _build context_-a i koristi se u _Dockerfile_-u.

```bash
docker buildx /files
```

- Keširanje radi bolje jer je ograničen samo na promene unutar tog foldera i igrnoriše potrebu za _Dockerignore_ fajlom.

- Postoje razlličiti tipovi _build context_-a (#link("https://docs.docker.com/build/building/context/")[docs]).

== Dockerfile - Alias

#raw(
"FROM python
ENV update='apt-get update -qq'
ENV install='apt-get install -qq'
RUN $update && $install apt-utils \\
  curl \\
  gnupg
",
  lang: "dockerfile",
  block: true
)

- Korišćenje alias komandi u _Dockerfile_-u je moguće pomoću `ENV`. 

- Nije moguće koristit `alias ll=ls -alh >> .bashrc` jer je to moguće samo u interaktivnom režimu kada se nakači na kontejner pomoću `docker run -it` ili `docker exec` komandi.

== Dockerfile - Pipe

#raw(
"FROM python
SHELL [\"/bin/bash\", \"-o\", \"pipefail\", \"-c\"]
#SHELL [\"/bin/ash\", \"-o\", \"pipefail\", \"-c\"] za alpine
RUN curl -L ${SRC_URL} tar -xz
",
  lang: "dockerfile",
  block: true
)

- Kada se koristi _pipe_ u `RUN` komandi neophodno je podesiti _shell_ tako da ukoliko komanda pre _pipe_-a ne završi uspešno da se ne nastavi sa izvrsavanjem _Dockerfile_-a.

== Dockerfile - ONBUILD

- Kako definisati generičke slike?
 - Na primer sliku za izvršavanje Python aplikacija u produkciju (utegnut _security_, ispoštovane najbolje prakse itd.).
 - Sve Python aplikacije u produkciji treba da koriste ovu sluku.

- Problem predstavljaju stvari koje su specifične za aplikaciju (_source code_  i _dependencies_, konfiguracioni fajlovi). Kako njih ubaciti u generičku sliku?

- `ONBUILD` komanda u _Dockerfile_-u definiše trigere koji će se izvršiti prilikom nasleđivanja slike. Koristi se za definisanje generičke slike koja će se naslediti i podesiti u skladu sa potrebama. Ide dobro u kombinaciji sa _multi-stage build_-om.

== Dockerfile - ONBUILD

#raw(
"FROM python3.9-alpine3.13
LABEL maintainer \"danijelradakovic@uns.ac.rs\"

ONBUILD ADD requirements.txt /app
ONBUILD RUN pip install -r /app/requirements.txt
ONBUILD COPY . /app

WORKDIR /app
EXPOSE 5000
ENTRYPOINT [\"python\"]
CMD [\"application.py\"]
",
  lang: "dockerfile",
  block: true
)

== Dockerfile - ONBUILD

- U konkretnom primeru je generička slika za Python aplikacije: fiksiran je OS, Python verzija, dok se _source code_ i intaliranje _dependency_-ja radi prilikom nalseđivanja ove slike.

- Neophodno ju je samo naslediti (`FROM python-prod`) u _Dockerfile_-u konkretne aplikacije.

- Naravno, uvek se slika može naslediti i pregaziti kako bi se prilagodili potrebama aplikacije (npr. izmeniti `CMD` komandu).

== Dockerfile - Concurent Builds

#raw(
"FROM maven:3.6-jdk-8-alpine AS builder
...
FROM alpine:latest AS assets
RUN echo \"Hello World\" > /out/assets.html

FROM openjdk:8-jre-$alpine AS release
COPY --from=builder /app/target/app.jar
COPY --from=assets /out /assets
CMD java -jar /app/app.jar
",
  lang: "dockerfile",
  block: true
)

- BuildKit može konkuretno da izvršava _stage_-ove. Postoji vise `--from` u nekom _stage_-u, konkuretno ce se izvrisit svaki `--from`.

== Dockerfile - Concurent Builds

- Preporuka je da `--from` bude jedni ispod drugih.

- Preporuka je da sve što treba da se kopira iz prethodno _stage_-a stavi u `/out` folder i onda kopirati `/out` folder u trenutni stage. U suprotnom bi postojale više `--from` naredbe koje bi kopirale pojedinačne fajlove ili folder koji su razbacani u prethom _stage_-u.

== Dockerfile - CI/CD

#raw(
"FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
COPY pom.xml
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package -DskipTests

FROM openjdk:8-jre-buster AS release-buster
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar

FROM openjdk:8-jre-alpine AS release-alpine
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar
",
  lang: "dockerfile",
  block: true
)

- Poželjno je imati barem poseban _stage_ za svaki OS koji se koristi, npr. za debian
  (`release-buster`) i za alpine (`release-alpine`). 

- Naredni primer je parametrizovana verzija prethodnog.

== Dockerfile - CI/CD

#raw(
"ARG flavor=alpine

FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
COPY pom.xml
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package -DskipTests

FROM openjdk:8-jre-${flavor} AS release
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar
",
  lang: "dockerfile",
  block: true
)

== Dockerfile - CI/CD Test Stage

#raw(
"ARG flavor=alpine

FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
COPY pom.xml
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package -DskipTests

FROM builder AS unit-test
RUN mvn -e -B test

FROM openjdk:8-jre-${flavor} AS release
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar

FROM release AS integration-test
# add dependencies for integration tests
RUN apk add --no-cache curl
RUN ./test/run.sh
",
  lang: "dockerfile",
  block: true
)

== Dockerfile - CI/CD Lint Stage

#raw(
"FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
COPY pom.xml
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package

FROM openjdk:8-jre-alpine AS lint
RUN wget https://github.com/checkstyle/checkstyle/releases/download/checkstyle-8.15/checkstyle-8.15-all.jar
COPY checks.xml
COPY src /src
RUN java -jar checkstyle-8.15-all.jar -c checks.xml /src
",
  lang: "dockerfile",
  block: true
)

== Dockerfile - RUN Mount Types

#raw(
"FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
RUN --mount=source=pom.xml/,target=. mvn -e -B dependency:resolve
RUN --mount=source=./src mvn -e -B package -DskipTests

FROM openjdk:8-jre-$alpine AS release
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar
",
  lang: "dockerfile",
  block: true
)

- `RUN` komanda ima opciju `--mount` koji kreira _bind volume_ u kontejneru 

- Koristi se kako bi se eliminisale _COPY_ komande u _Dockerfile_-u.

== Dockerfile - RUN Mount Types

#raw(
"FROM maven:3.6-jdk-8-alpine AS builder
WORKDIR /app
RUN --mount=target=. \\
    --mount=type=cache,target=/root/.m2 \\
      mvn package -DoutputDirectory=/
FROM openjdk:8-jre-$alpine AS release
COPY --from=builder /app/target/app.jar
CMD java -jar /app/app.jar
",
  lang: "dockerfile",
  block: true
)

- Još bolja opcija je da se koristi application _cache_.

== Dockerfile - RUN Mount Types

- Većina alata ima svoj _cache_ folder a neki od njih su:
  - apt: `/var/lib/apt/lists`
  - go: `~/.cache/go-build`
  - go-modules: `$GOPATH/pkg/mod`
  - npm: `~/.npm`
  - pip: `~/.pip`

== Dockerfile - RUN Mount Types

- Kako rukovati sa _secret_-ima u `RUN` komandi?
  - Primer: potrebni su nam kredencijali kako bi pomoću _curl_ komadne skinuli nešto sa privatnog skladišta?
  - Primer: pomoću SSH ključa treba da skinemo kod sa privatnog repozitorijuma?

- _Secret_-i se ne mogu proslediti kao argumenti slike jer se argumetni čuvaju u metapodacima slike i moguće im pristupiti preko `docker image inspect`.

- Ne mogu se kopirati pomoću `COPY` komande i zatim obrisati pomoću `RUN` komande u narednom koraku jer će `COPY` generisati novi _layer_. Za pristum pojedinačnom _layer_-u slike može se koristiti #link("https://github.com/containers/skopeo")[scopeo] alat i videti sam sadržaj _secret_-a.

== Dockerfile - RUN Mount Types

- Pristup da se nakon RUN komande obriše secret (npr. `rm ssh-key`) će prouzrokovati da _secret_ neće biti vidljiv u finalnom _layer_-u, ali će svakako biti vidlji u prethodnom _layer_-u (tj. _layer_-u `COPY` komande), kome će se opet može pristupiti pomoću skopeo alata.

- Problem nastane kad se ovakve slike okače na javni _registry_ i svako može da se dočepa _secret_-a!!!

- Rešenje je korišćenje `--mount=type=secret`.

== Dockerfile - RUN Mount Types

#raw(
"FROM migration-base as execute-migration
ARG DATABASE_HOST=database
ARG MIGRATION=init
ENVENVDATABASE_HOST=${DATABASE_HOST}
MIGRATION=${MIGRATION}
RUN --mount=type=secret,id=db-psw,dst=/.secrets/db-psw,required \\
    --mount=type=secret,id=db-user,dst=/.secrets/db-user,required \\
    --mount=type=secret,id=db-schema,dst=/.secrets/db-schema,required \\
       PATH=\"$PATH:/root/.dotnet/tools\"; \\
       export DATABASE_PASSWORD=$(cat /.secrets/db-psw); \\
       export DATABASE_USERNAME=$(cat /.secrets/db-user); \\
       export DATABASE_SCHEMA=$(cat /.secrets/db-schema); \\
       dotnet-ef migrations add ${MIGRATION} \\
         -p \"${PROJECT}/${PROJECT}.csproj\" \\
         --configuration Release \\
         --no-build && \\
       dotnet-ef database update ${MIGRATION} \\
         -p \"${PROJECT}/${PROJECT}.csproj\" \\
         --configuration Release \\
         --no-build
",
  lang: "dockerfile",
  block: true
)

== Dockerfile - Private Git Repo with SSH Forwarding

#raw(
"FROM alpine
RUN apk add --no-cache openssh-client
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
ARG REPO_REF=19ba7dcd9976eff829bd86541df1ba # main, develop, etc.
RUN --mount=type=ssh,required \\
      git clone git@github.com:org/repo /work && cd /work \\
      && git checkout -b $REPO_REF
",
  lang: "dockerfile",
  block: true
)

```bash
# How to use it in shell
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
docker build --ssh=default
```

== APT Package Manager

#raw(
"FROM python
RUN apt-get update -y && apt-get install -y --no-install-recommends \\
      curl=7.64.0-4+deb10u2 \\
      tar=1.30+dfsg-6 && \\
      apt-get clean && \\
      rm -rf /var/lib/apt/lists/*
",
  lang: "dockerfile",
  block: true
)

- Kada se radi sa _package manager_-om ne treba intalirati _recomends_ pakete (npr. `apt-get --no-recomends`), kao i obrisati _cache_ (`/var/lib/apt/list/*`).

- Fiksrirati verzije paketa kada se instaliraju pomoću _package manager_-a.

== Maven Package Manager

#raw(
"FROM maven:3.6-jdk-8-alpine
WORKDIR /app
COPY pom.xml
RUN mvn -e -B dependency:resolve
COPY src ./src
RUN mvn -e -B package
",
  lang: "dockerfile",
  block: true
)

- Dobra je praksa da se _dependency_-ji iz `pom.xml` fajla kesiraju tako sto ce se koristiti `dependency:resolve plugin` (#link("https://medium.com/javarevisited/8-commands-that-help-to-resolve-maven-dependency-problems-fc56676bc647")[usefull comands]).

== Docker Build - Optimizacija

- Optimizacija kroz #link("https://docs.docker.com/build/cache/")[cache].

- Keširanje dosta jede memorije pa treba obratiti pažnju i na #link("https://docs.docker.com/build/cache/garbage-collection/")[garbage collector].

- Spomenut je `RUN --mount=type=cache` koji koristi _bound volume_ u pozaditi. _Bound volume_ skladišti podatke na lokalnoj mašini što je odlično za _build_ sa lokalne mašine ali problem nastaje prilikom izvršavanja u CICD jer _runner_-i koji izšavaju _job_-ove mogu biti različiti i lokalni _cache_ nije isti.

- Za CI-CD se najčešće koristi #link("https://docs.docker.com/build/cache/backends/")[remote storage backend] - `inline`.

= Docker Compose

== Docker Templating

- `docker config`: generiše compose fajl na osnovu compose _template_-a i i _env_ fajla.

```env
# env.conf.template
STAGE=prod
POSTGRES_VERSION=13
```

== Docker Templating

```yaml
# persistance.yaml
services:
  database:
    image: postgres:${POSTGRES_VERSION:-12} # default: 12
  environment:
    POSTGRES_PASSWORD_FILE: /run/secrets/database-password
    POSTGRES_USER_FILE: /run/secrets/database-username
    POSTGRES_DB_FILE: /run/secrets/database-schema
  volumes:
    - database-data:/var/lib/postgresql/data

volumes:
  database-data:
    name: clean_cadet_database_${STAGE:-dev} # default: dev
```

== Docker Templating


- `docker compose --env-file env.template.conf --file persistance.yml config > compose.yml`

```yaml
services:
  database:
    image: postgres:13
    environment:
      ...
    volumes:
      - database-data:/var/lib/postgresql/data

volumes:
  database-data:
    name: clean_cadet_database_prod
```

= Docker Swarm

== Docker Swarm

- Koristi se za formiranje *swarm* klustera (umreženih servera - čvorova) i deployment servisa na kluster.

- Postoje 2 tipa čvora:
 - Master: koristi se za upravljanje klustera ( samo na _master_ čvorovima mogu se izvršavati Docker komande)
  - Među _master_ čvorovima postoji lider koji donosi odluke
  - Izbor novog lidera među _master_ čvorovima se odvija pomću Raft protokola.
 - Slave: koriste za izvršavanje aplikacija.

- Saobraćaj se odvija kroz 2 kanala:
 - control plane: Docker komande, komunikacija koja se odvija između _master_ čvorova.
 - data plane: saobraćaj samih aplikacija.
 
== Docker Swarm

- Preporučuje da da bude uvek neparan broj _master_ čvorova zbog segmentacije mreže.

- Ne preporučuje se da ima više od 7 master čvorova jer nema benefita, samo otežava sihronizaciju.

- Infrastruktura se definiše u _yaml_ fajlu koji se naziva *stack* (sličan _compose_ fajlu).
 - deployment stack-a: `docker stack deploy stack.yml`
 - svaki servis mora da sadrži `deploy` sekciju u kojem se definise _deployment_ samog servisa unutar klustera.
 - postoje 2 tipa _deployment_-a:
  - replicated (default): definiše broj replika i _swarm_ ih raspoređuje unutar klustera,
  - global: na svakom serveru unutar klastera će se nalaziti kontejner.
  
== Docker Secrets

- Koristi se čuvanje osetljivih informacija i transfer do servisa kojima su te informacije potrebne (#link("https://docs.docker.com/engine/swarm/secrets/")[docs]).

```bash
printf "%s" "${DATABASE_PASSWORD}" \
| docker secret create "clean_cadet_database_password_dev" - > /dev/null
printf "%s" "${DATABASE_USERNAME}" \
| docker secret create "clean_cadet_database_username_dev" - > /dev/null
printf "%s" "${DATABASE_SCHEMA}" \
| docker secret create "clean_cadet_database_schema_dev" - > /dev/null
```

- Ovi _secret_-i se mogu koristiti u bilo kom _stack_-u, ali se moraju označiti kao external (primer na sledećem slajdu).

== Docker Secrets

```yaml
services:
  database:
    image: postgres:${POSTGRES_VERSION:-13}
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/database-password
      POSTGRES_USER_FILE: /run/secrets/database-username
      POSTGRES_DB_FILE: /run/secrets/database-schema
  secrets:
    - source: database-password
      target: database-password
    - source: database-username
      target: database-username
    - source: database-schema
      target: database-schema

secrets:
  database-password:
    name: clean_cadet_database_password_dev
    external: true
  database-username:
    name: clean_cadet_database_username_dev
    external: true
  database-schema:
    name: clean_cadet_database_schema_dev
    external: true
```

== Docker Secrets

- _Secret_-i se ne mogu obrisati sve dok postoji barem jedan servis koji ih koristi!

- Za izmenu _secret_-a neophodno je:
 - obrisati sve servise koji koriste taj _secret_,
 - obrisati sam _secret_,
 - kreirati novi _secret_ sa željenim sadžajem,
 - kreirati sve servise koji koriste taj _secret_.

== Docker Secrets

- Pristup koji olakšava upravljanje jeste da se u samom nazivu _secret_-a koristi verzija:
 - krerati novi _secret_ sa željenim sadržajem i verzijom,
  - za svaki servis kreirati novi i obristati stari _secret_:
   - u _stack_ fajlu ubaciti novu verziju i izmeniti konfiguraciju servisa da koriste novi _secret_, _swarm_ će uspeti da napravi odgovarajuću izmenu (u pozadini će izvršiti sledeću komandu).
   - `docker service update --secret-rm source=<old> --secret-add source=<new>`.
 - obrisati stari secret.
 
== Docker Configs
 
- Kako rukovati sa konfiguracionim fajlovima unutar servisa koji se često menjanju. Na primer konfiguracija _nginx_-a?
 - Pomoću _docker compose_-a se ovaj problem lako rešava koristeći _bind volume_.
 - Međutim u _swarm_-u se ne koristi _bind volume_ zato što se vezuje _host file system_, pa je samim tim nemoguće distibuirati konfiguracione fajlove servisima koji se izvršavaju na drugim čvorovima u klusteru.

- Jedno od rešenja je da se konfiguracioni fajlovi zapakuju u sliku kontejnera i menjati verziju slike svaki put kad je neophodno izmeniti konfiguracioni fajl (naporan posao kada se konfiguracija često menja).

== Docker Configs

- Za ovakve potrebe koristiti Docker Configs (#link("https://docs.docker.com/engine/swarm/configs/")[docs]) koji distriburia konfiguracione fajlove servisima kojima su neophodni.

```yaml
services:
  gateway:
    image: nginx:${VERSION-16}
    configs:
      - source: nginx.conf
        target: /etc/nginx/nginx.conf
      - source: api_gateway.conf
        target: /etc/nginx/api_gateway.conf

configs:
  nginx.conf:
    name: nginx.conf-prod
    file: ./gateway/files/config/nginx.conf # fajl mora da bude na master nodu gde se radi deploy stack-a
  api_gateway.conf: # alternativa je da kreiraju van stack-a i imprt-uju pomoću external
    name: api_gateway.conf-prod
    file: ./gateway/files/config/api_gateway.conf
```

== Docker Configs

```yaml
configs:
  nginx.conf:
    name: nginx.conf-prod
    file: ./gateway/files/config/nginx.conf
  api_gateway.conf:
    name: api_gateway.conf-prod
    file: ./gateway/files/config/api_gateway.conf
```

- Config će se update-ovati samo kade se promeni naziv _config_-a.
 - Primer: Ukoliko se promeni sadržaj `api_gateway.conf` fajla i uradi _deploy stack_-a neće se uraditi izmene je je naziv ostao isti (`api_gateway.conf-prod`).
 - Drugim rečima _config_ je _inmutable_.

- _Config_ nije moguće obrisati ako ga neki servis koristi.

== Docker Configs

- Može koristiti verzije u nazivima _config_-a kako bi se rešili ovi problemi.

- Umesto verzija moguće je koristiti _hash_ sadržaja konfiguracionog fajla (kao sufiks u imenu). Na ovaj način će se naziv _config_-a menjati kada se izmeni sam sadržaj fajla.

```yaml
configs:
  nginx.conf:
    name: nginx.conf-prod-<hash-from-nginx.conf-file>
    file: ./gateway/files/config/nginx.conf
  api_gateway.conf:
    name: api_gateway.conf-prod-<hash-from-api_gateway.conf-file>
    file: ./gateway/files/config/api_gateway.conf
```

== Docker Configs

```yaml
configs:
  nginx.conf:
    name: nginx.conf-${nginx_conf_DIGEST}
    file: ./gateway/files/config/nginx.conf
  api_gateway.conf:
    name: api_gateway.conf-${api_gateway_conf_DIGEST}
    file: ./gateway/files/config/api_gateway.conf
```

- Ideja implementacije (#link("https://github.com/Clean-CaDET/tutor/blob/operations/util/docker-config-hash/files/docker-config-hash.sh#L50")[source]):
  - Postaviti DIGEST _placeholder_-e u _stack template_-u kako bi se znalo za koje _config_-e je neophodno generisati _hash_ sufiks.
  - Generiši _hash_ na osnovu sadržaja fajla.
  - Uradi skraćivanje _hash_ sufiksa tako da kompletan naziv _config_-a ima 64 karaktera (64 je maksimalna broj karaktera dozvoljen za naziv _config_-a).
  - Izgeneriši env fajl koji mapira _placeholder_-e na _hash_.
    - `nginx_conf_DIGEST=truncedhashfromnginx`,
    - `api_gateway_conf_DIGEST=truncedhashfromapigateway`
  - kombinacijom _env_ fajla i _stack template_-a geniriši finalni _stack_ (naredni slajd)
  
== Docker Configs

-  Postoji već gotov kontejner koji radi generisanje env fajla (#link("https://github.com/Clean-CaDET/tutor/blob/operations/smart-tutor/stacks/public/scripts/deploy.sh#L60")[source]).

```bash
docker create –name config-hash cleancadet/docker-config-hash:latest # kreira kontejner, ne pokreće ga
docker cp ../ config-hash # kopira sve neophodne fajlove
docker start config-hash # pokreće kontejner
docker cp config-hash:/tmp/env . # kopiraj rezultujući env fajl iz kontejnera na lokalni fajl sistem
docker rm config-hash # obriši kontejner koji više nije potreban
docker compose --env-file env \
  --file app.yml config \
  | docker stack deploy --prune -c - app-prod # kreiraj finalni stack i radi njegov deploy 
rm env # obriši env fajl jer više nije potreban
```

== Docker Configs i Docker Secrets

- Ukoliko se u konfiguracionom fajlu nalaze osetljive informacije i tom slučaju treba koristi opciju `--template-driver` i napistai Go template (#link("https://blog.sunekeller.dk/2018/04/docker-18-03-config-and-secret-templating/")[primer]).