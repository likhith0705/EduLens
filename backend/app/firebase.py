import os

import firebase_admin
from firebase_admin import credentials, firestore

BASE_DIR = os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)

SERVICE_ACCOUNT_PATH = os.path.join(
    BASE_DIR,
    "firebase-service-account.json",
)

PROJECT_ID = "edulens-95199"

if not firebase_admin._apps:
    # On Cloud Run, use the service account attached to the service.
    if os.getenv("K_SERVICE"):
        cred = credentials.ApplicationDefault()
    else:
        # Local development uses the existing service-account file.
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)

    firebase_admin.initialize_app(
        cred,
        {"projectId": PROJECT_ID},
    )

db = firestore.client()
