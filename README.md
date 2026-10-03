<img width="1101" height="195" alt="screen honeytoken" src="https://github.com/user-attachments/assets/0adcc37c-eab1-4930-963c-187c7304544d" />
## 🛡️ Contexte & Retour d'Expérience (REX)

### 📌 Version 1.0 (Architecture Initiale & Faille Identifiée)
La première version du projet visait à déployer un **Honey-Token IAM** (`service-admin-sauvegarde`) sur AWS afin de détecter les tentatives d'accès non autorisées via **CloudTrail** et **EventBridge**, avec notification en temps réel sur **Discord** via une fonction Lambda.

* **Faille de sécurité identifiée** : Les identifiants sensibles (URL du Webhook Discord et ID d'utilisateur Discord) étaient directement hardcodés dans le code source de la fonction `lambda_function.py`.
* **Risque** : Lors de la publication du code sur un dépôt public, l'historique Git conservait ces secrets en clair, exposant le canal de notification à des abus potentiels par des bots d'exploration automatisés.

---

### 🔒 Version 2.0 (Remédiation & Sécurisation)
Afin de transformer ce projet en une solution conforme aux bonnes pratiques de sécurité (DevSecOps) :

1. **Assainissement de l'historique Git** : Réinitialisation complète du dépôt Git local (`git init`) et suppression définitive de tout l'historique compromis.
2. **Gestion sécurisée des secrets** : Refonte du code Python pour extraire les secrets via `os.environ` (`DISCORD_WEBHOOK_URL` et `DISCORD_USER_ID`).
3. **Injection via Terraform** : Configuration des variables Terraform chiffrées/masquées (`sensitive = true`) pour alimenter le bloc `environment` de la fonction Lambda de manière dynamique.
4. **Audit de sécurité pré-publication** : Validation de l'absence totale de secrets résiduels dans le code et les commits à l'aide de l'outil **Gitleaks** (`leaks found: 0`).

5.<img width="1101" height="195" alt="Alerte Discord Honey-Token " src="https://github.com/user-attachments/assets/0adcc37c-eab1-4930-963c-187c7304544d" />
