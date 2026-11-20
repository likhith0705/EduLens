
from fastapi import APIRouter, HTTPException

from app.firebase import db

router = APIRouter(
    prefix="/performance",
    tags=["Performance"],
)


@router.get("/{email}")
def get_performance(email: str):
    email = email.lower()

    # Confirm that the student exists
    student_doc = (
        db.collection("students")
        .document(email)
        .get()
    )

    if not student_doc.exists:
        raise HTTPException(
            status_code=404,
            detail="Student not found",
        )

    # Fetch performance data from Firestore
    performance_doc = (
        db.collection("performance")
        .document(email)
        .get()
    )

    if not performance_doc.exists:
        return {
            "email": email,
            "overall_percentage": 0,
            "subjects": [],
        }

    data = performance_doc.to_dict()

    return {
        "email": email,
        "overall_percentage": data.get(
            "overall_percentage", 0
        ),
        "subjects": data.get("subjects", []),
    }
