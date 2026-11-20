
from functools import lru_cache

import cv2
import numpy as np
from insightface.app import FaceAnalysis


@lru_cache(maxsize=1)
def get_face_model():
    """Load the face model once per backend process."""
    model = FaceAnalysis(
        name="buffalo_l",
        providers=["CPUExecutionProvider"],
    )
    model.prepare(
        ctx_id=0,
        det_size=(640, 640),
    )
    return model


def generate_face_embedding(image_bytes: bytes) -> list[float]:
    """Detect exactly one face and return its normalized embedding."""
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("The uploaded file is not a valid image.")

    model = get_face_model()
    faces = model.get(image)

    if len(faces) == 0:
        raise ValueError("No face detected. Please upload a clear face photo.")

    if len(faces) > 1:
        raise ValueError(
            "Multiple faces detected. Please upload a photo containing only one person."
        )

    embedding = faces[0].normed_embedding

    if embedding is None:
        raise ValueError("Could not generate a face embedding.")

    return embedding.astype(np.float32).tolist()
