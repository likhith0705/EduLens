from fastapi import FastAPI
from app.routers import auth, students, face, attendance, performance

app = FastAPI(
    title="EduLens API",
    description="AI-powered college attendance system",
    version="1.0.0"
)

app.include_router(auth.router)
app.include_router(students.router)
app.include_router(face.router)
app.include_router(attendance.router)
app.include_router(performance.router)


@app.get("/")
def root():
    return {
        "message": "EduLens API is running",
        "version": "1.0.0"
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "database": "firebase"
    }
