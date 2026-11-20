
from pathlib import Path

from app.services.face_recognition import recognize_classroom_image

image_path = Path(r"C:\EduLens\test_face.jpg")

if not image_path.is_file():
    raise FileNotFoundError(f"Image not found: {image_path}")

result = recognize_classroom_image(image_path.read_bytes())

print(f"Faces detected: {result['faces_detected']}")
print(
    "Registered embeddings checked:",
    result["registered_embeddings_checked"],
)

for match in result["matches"]:
    print({
        "name": match["name"],
        "email": match["email"],
        "status": match["status"],
        "similarity": match["similarity"],
        "bbox": match["bbox"],
    })
