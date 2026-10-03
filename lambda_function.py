import os
import json
import urllib3

# Récupération des secrets via les variables d'environnement Lambda
URL_WEBHOOK = os.environ.get("DISCORD_WEBHOOK_URL")
MON_ID_DISCORD = os.environ.get("DISCORD_USER_ID")

def lambda_handler(event, context):
    details = event.get('detail', {})
    nom_evenement = details.get('eventName', 'Action Inconnue')
    nom_utilisateur = details.get('userIdentity', {}).get('userName', 'Utilisateur Inconnu')
    adresse_ip = details.get('sourceIPAddress', 'IP Inconnue')
    region = details.get('awsRegion', 'Region Inconnue')
    
    message = {
        "content": f"🚨 <@{MON_ID_DISCORD}> **ALERTE SÉCURITÉ : Honey-Token Déclenché !** 🚨\n"
                   f"• **Compte piège utilisé** : `{nom_utilisateur}`\n"
                   f"• **Action tentée** : `{nom_evenement}`\n"
                   f"• **Adresse IP de l'attaquant** : `{adresse_ip}`\n"
                   f"• **Région** : `{region}`"
    }
    
    if URL_WEBHOOK:
        http = urllib3.PoolManager()
        reponse = http.request(
            'POST',
            URL_WEBHOOK,
            body=json.dumps(message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Alerte envoyée sur Discord !')
    }