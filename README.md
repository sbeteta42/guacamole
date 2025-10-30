 🧩 Apache Guacamole – Installation Automatisée sur Debian 12

![Linux](https://img.shields.io/badge/OS-Debian_12-red?logo=debian)
![Guacamole](https://img.shields.io/badge/Version-1.5.5-green?logo=apache)
![Tomcat](https://img.shields.io/badge/Tomcat-9-yellow?logo=apachetomcat)
![MariaDB](https://img.shields.io/badge/DB-MariaDB-blue?logo=mariadb)
![License](https://img.shields.io/badge/License-MIT-lightgrey)
![Status](https://img.shields.io/badge/Status-Stable-success)

---

## 🧠 À propos

Ce dépôt contient un **script Bash entièrement automatisé et commenté** pour déployer **[Apache Guacamole](https://guacamole.apache.org/)** sur **Debian 12 (Bookworm)*
L’objectif est de permettre aux formateurs, administrateurs et étudiants en cybersécurité / ingénierie système de :
- disposer d’un **bastion d’accès distant sécurisé** (RDP, SSH, VNC) via navigateur,
- déployer une **stack complète Guacamole + Tomcat 9 + MariaDB** sans configuration manuelle,
- disposer d’un **script reproductible, documenté et auditable** pour des TPs ou environnements de production.

---

## ⚙️ Stack installée automatiquement

| Composant             | Version / Source                            | Description |
|------------------------|---------------------------------------------|--------------|
| **Guacamole Server**  | 1.5.5 (compilé depuis sources)              | Backend RDP, SSH, VNC, Telnet, Websockets |
| **Guacamole Client**  | 1.5.5 (WebApp WAR pour Tomcat 9)            | Interface Web HTML5 |
| **Tomcat**            | 9.x (dépôt Debian 11 "bullseye")            | Conteneur Java supporté |
| **MariaDB**           | 10.x                                       | Base d’authentification et stockage des connexions |
| **JDBC MySQL Connector** | 9.1.0                                   | Connecteur JDBC requis par Guacamole |
| **Systemd / guacd**   | Service système auto-démarré               | Démon d’interprétation des connexions |

---

## 📦 Installation rapide

### 1️⃣ Cloner le dépôt
```bash
git clone https://github.com/sbeteta42/guacamole.git
cd guacamole
chmod +x install_guacamole.sh
./install_guacamole.sh
```
