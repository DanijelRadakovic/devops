# ShopHub

Tema projekta je platforma koja omogućava dinamčko kreiranje (deployment) prodavnica od strane krajnih korisnika.

## Arhitektura

- **ShopHub**: Predstavlja Web aplikaciju (front-end i back-end) na kojoj korisnik upravlja svojim sajtovima za prodavnice.
  Korisnik može da dodaje nove, briše i menja konfiguraciju sajtova za prodavnice. Na primer, korisnik preko admin panela
  može da kreira dva sajta za prodavnice: prodavnica odeće i prodavnica zdrave hrane.
- **Shop**: Predstavlja Web aplikaciju (fron-end i back-end) u kojoj vlasnik prodavnice moze upravlja artiklima prodavnice.
  Krajni korisnici mogu da koriste prodavnicu radi kupovine artikala. Kupovina artikala se radi pomoću kriptovaluta.

## Uloge u sistemu

- **ShopHub**:
  - **Korisnik**: Kreira, menja i briše sajtove za prodavnice.
- **Shop**:
  - **Admin**: Kreira, menja i briše artikle prodavnice.
  - **Korisnik**: Bira artikle iz prodavnice koje želi da kupi i vrši plaćanje tih artikala.

## Funkcionalni zahtevi - ShopHub

### 1.1 Prijva i registracija korisnika

Korisnik mora da se authentifikuje kako bi pristupio panelu za upravljanje sajtovima prodavnica.
Ukoliko nema napravljen nalog, korisnik se mora prethodno registrovati.

**Opciono**: Raditi authentifikaciju preko Web3 wallet-a.

### 1.2 Upravljanje sajtovima prodavnica

Admin može da kreira sajt prodavnice i pokrene deployment aplikacije za prodavnicu i svih njenih komponenti unutar Kubernetes klastera. 
Prilikom kreiranja prodavnice admin podešava:
- naziv prodavnice, 
- dostupnost aplikacije: `standard` (2 replike) ili  `high` (3 replike). 
- adresu wallet-a na kojem ležu uplate od korisnika,
- bazu koju želi da koristi: `standard` (PostgreSQL), `light` (Redis).

Admin ima opciju da klikne na sajt i da mu se u novom tab-u otvori sajt prodavnice. 
Takođe, admin ima opciju da konfiguriše sajt prodavnice npr. da menja dostupnost aplikacije ili adresu wallet-a.
Omogućiti adminu i brisanje sajtova prodavnica.

**Napomena**: Za deployment prodavnica se moraju koristit CRD-jevi definisani u [Shop operatoru](#31-shop-operator).

**Napomena**: Za deployment baza moraju se koristiti njihovi operator, npr. za PostgreSQL koristi [CNPG]("https://cloudnative-pg.io/"), za Redis koristiti [REDB]("https://redis.io/docs/latest/operate/kubernetes/re-databases/db-controller/").

**Napomena**: Umesto Redis baze može se koristiti neka druga baza (npr. MongoDB) ali je obanezno koristiti operator te baze za deployment.

## Funkcionalni zahtevi - Shop

### 2.1 Upravljanje artiklima

Admin može da dodaje, briše ili menja artikle. Artikal treba da ima naziv, broj komada na raspolaganju i cenu.

### 2.2 Pregled porudžbina

Admin može da izlistava kreirane porudžbine.

### 2.3 Odabir artikala

Korisnik može da pretražuje artikle i da ih doda u korpu.

### 2.4 Kupovina artikala

Korisnik može da izvriši plaćanje artikala (iz korpe) u nekoj kripto valuti, na primer USDT. 
Za integraciju se može koristiti bilo koji blockchain i bilo koji Web3 wallet. 
Dovoljno je da radi na testnet-u, nije u obavezi da radi na mainnet-u.  

Preporuka za Web3 wallet: [Metamask]("https://metamask.io/") ili [Phantom]("https://phantom.com/").

## Funkcionalni zahtevi - Kubernetes

### 3.1 Shop operator

Neophodno je pružiti podršku za sledeće CRD-jeve:
- **Shop**: Kreira Shop aplikaciju. Ukoliko je dostupnost **standard** kreira 2 replike aplikacije, za **high** kreira 3.
- **DiscordChannel**: Kreira kanal za notifikacije na Discord serveru.
- **Wallet**: Kreira account na blockchain-u na kojem korisnici vrše uplatu.

**Napomena**: Može se koristit neka druga platrofma za notifikacije pored Discord-a.

### 3.2 Shop operator Helm Chart

Napraviti Helm Chart koji radi deployment Shop operatora i instalaciju CRD-jeva.

### 3.3 ShopHub Helm Chart

Napraviti Helm Chart koji koristi CRD-jeve iz Shop operatora i [prometheus-stack]("https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack")-a.

## Nefunkcionalni zahtevi

### 4.1 Observability stack

Obezbediti tracing, logging i metrike za svaku Shop aplikaciju koja je kreirana i prikazati na Grafana dashboard-u.
Svaka Shop aplikacija treba da ima svoj dashboard. Pristup grafani imaju samo maintainer-i koji održavaju aplikacije. 
Korisnici ShopHub-a nemaju pristup Grafana dashboard-u.

**Opciono**: Omogućiti da korisnici ShopHub-a mogu da pristupe Grafana dashboardima **samo** svojih aplikacija. Neophodno je pravilno konfigurisati prava pristupa.

Omogućiti sledeće metrike Shop aplikacije:

- Metrike koje obezbeđuju informacije o iskorišćenju procesora, RAM memorije, fajl sistema i protok mrežnog saobraćaja.
- Mektrike Web saobraćaja u mikroservisnoj aplikaciji:
  - Ukupan broj HTTP zahteva u prethodnih 24 sata.
  - Broj uspešnih HTTP zahteva u prethodnih 24 sata (2xx, 3xx).
  - Broj neuspešnih zahteva u prethodnih 24 sata (4xx, 5xx).
  - Broj jedinstvenih posetilaca (ista IP adresa, timestamp i web browser).
  - Broj neuspešnih zahteva sa statusom 404 sa njihovim endpoint-ovima u prethodnih 24 sata.
  - Ukupan protok saobraćaja izražen u GB.
  - Ostale metrike koje mislite da su od značaja.

Neophodno je konfigurisati alarme koji će slati notifikacije na odgovarajući Discord kanal aplikacije.
Definisanje pravila za okidanje alarma se ostavljaju studentima.
 
Pored metrika Shop aplikacije neophodno je prikazati metrike samog Kubernetes klastera koji se koristi (minikube, kind, k3s).
Minimum treba obezbedtiti informacije o iskorišćenju procesora, RAM memorije, fajl sistema i protok mrežnog saobraćaja.
Takođe neophodno je definisati alarme vezani za sam Kubernetes klaster.


## DevOps zahtevi

### 5.1 Konfiguracija Git repozitorijuma

- Koristiti [Trunk Based Development]("https://trunkbaseddevelopment.com/").
- PR (Pull Request) mora da se odobri od barem jednog člana tima.
- Podesiti pipeline koji će se okidati prilikom kreiranja svakog PR-a i njegovih izmena. 
Pipeline treba da build-uje aplikaciju, pokrene unit i integracione testove. 
Podesitit opciju da u slučaju da pipeline ne prolazi, PR se ne može integrisati.
- Uključiti linearnu istoriju (linear history) master i develop grana.
- Koristiti [Conventional Commits]("https://www.conventionalcommits.org/en/v1.0.0/") za sadržaj commit poruka.
- Neophodno je da svaki mikroservis ima svoj repozitorijum.

### 5.2 Konfiguracija CI pipeline-ova

Za ShopHub, Shop i Shop operator repozitorijume neophodno je napraviti CI pipeline koji će obuhvati:
- Build aplikacije, pokretanje unit i integracionih testova. 
Za kreiranje neophodne infrastrukture (baza, message brokera itd.) za izvršavanje
integracionih testova koristiti Testcontainers ili docker compose.
- Kreiranje slike kontejnera i publish-ovanje na DockerHub ili neki drugi container registry.
Koristiti [Semantic Versioning]("https://semver.org/") prilikom verzionisanja kontejnera.

### 5.3 Organizacija IaC 

Sve Helm Chart-ove koje sami pišite moraju da se nalaze na `helm-chart` repozitorijumu. Struktura bi bila sledeća:

```
helm-charts
├── README.md
└── charts/
    ├── bitcoin/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    ├── celestia/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    ├── shop/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    └── shophub/
        ├── Chart.yaml
        ├── values.yaml
        ├── charts/
        └── templates/
            ├── NOTES.txt
            ├── _helpers.tpl
            ├── deployment.yaml
            ├── hpa.yaml
            ├── ingress.yaml
            ├── service.yaml
            └── serviceaccount.yaml
```

Stanja Kubernetes klastera se upravlja na `kube-state` repozitorijumu. Struktura bi bila sledeća:

```
kube-state
├── README.md
└── clusters/
    └── local/
        ├── cluster.yaml # metapodaci samog klustera
        ├── shop-operator/
        │   ├── helm.yaml # Naziv charta u OCI formatu
        │   └── values.yaml # value overrides
        ├── shophub/
        │   ├── helm.yaml
        │   └── values.yaml
        └── shophub-discord/
            ├── helm.yaml
            └── values.yaml
```

**Opciono**: U `kube-state` repozitorijumu možete koristiti neki od GitOps alata (ArgoCD ili Flux) i pratiti njihovu strukturu foldera i fajlova.

## Pravila polaganja
- Projekat se radi u timovima do 3 člana.
- Projekat možete implementirati u bilo kom programskom jeziku i radnom okviru. Ako se odlučite za tehnologiju koja nije pokrivena na vežbama, pomoć u tom slučaju je ograničena.
- **Zahtev [5.3 Organizacija IaC](#53-organizacija-iac-) je eliminacioni. Projekti koji ne ispoštuju ovaj zahtev se neće ni pregledati**.
- Projekat nosi ukupno 50 bodova. Projekat se smatra položenim ako ste osvojili 15 ili više bodova.
- Pored termina u julu, odbarana projekta će se održati u septembru i u januaru ili februaru.
- Za sve slučajeve koji nisu pokriveni u specifikaciji, studentima se daje mogućnost da ih reše na način koji je njima najprikladniji.
