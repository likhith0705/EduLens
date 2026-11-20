from datetime import date, datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Float,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


# ============================================================
# USERS
# ============================================================

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)

    google_id: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
    )

    profile_photo_url: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    student: Mapped["Student | None"] = relationship(
        back_populates="user",
        uselist=False,
    )

    faculty: Mapped["Faculty | None"] = relationship(
        back_populates="user",
        uselist=False,
    )


# ============================================================
# SECTIONS
# ============================================================

class Section(Base):
    __tablename__ = "sections"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    name: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    department: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    semester: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    academic_year: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    students: Mapped[list["Student"]] = relationship(
        back_populates="section",
    )

    faculty_subjects: Mapped[list["FacultySubject"]] = relationship(
        back_populates="section",
    )

    class_sessions: Mapped[list["ClassSession"]] = relationship(
        back_populates="section",
    )

    __table_args__ = (
        UniqueConstraint(
            "name",
            "department",
            "semester",
            "academic_year",
        ),
        CheckConstraint(
            "semester BETWEEN 1 AND 8",
        ),
    )


# ============================================================
# STUDENTS
# ============================================================

class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    usn: Mapped[str] = mapped_column(
        String(30),
        unique=True,
        nullable=False,
    )

    department: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    semester: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    section_id: Mapped[int | None] = mapped_column(
        BigInteger,
        ForeignKey("sections.id", ondelete="SET NULL"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="student",
    )

    section: Mapped["Section | None"] = relationship(
        back_populates="students",
    )

    face_embeddings: Mapped[list["FaceEmbedding"]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan",
    )

    attendance_records: Mapped[list["Attendance"]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan",
    )


# ============================================================
# FACULTY
# ============================================================

class Faculty(Base):
    __tablename__ = "faculty"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    employee_id: Mapped[str | None] = mapped_column(
        String(50),
        unique=True,
        nullable=True,
    )

    department: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    user: Mapped["User"] = relationship(
        back_populates="faculty",
    )

    faculty_subjects: Mapped[list["FacultySubject"]] = relationship(
        back_populates="faculty",
        cascade="all, delete-orphan",
    )

    class_sessions: Mapped[list["ClassSession"]] = relationship(
        back_populates="faculty",
    )


# ============================================================
# SUBJECTS
# ============================================================

class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    code: Mapped[str] = mapped_column(
        String(30),
        unique=True,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    department: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    semester: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    faculty_subjects: Mapped[list["FacultySubject"]] = relationship(
        back_populates="subject",
        cascade="all, delete-orphan",
    )

    class_sessions: Mapped[list["ClassSession"]] = relationship(
        back_populates="subject",
    )


# ============================================================
# FACULTY ↔ SUBJECT ↔ SECTION
# ============================================================

class FacultySubject(Base):
    __tablename__ = "faculty_subjects"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    faculty_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("faculty.id", ondelete="CASCADE"),
        nullable=False,
    )

    subject_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("subjects.id", ondelete="CASCADE"),
        nullable=False,
    )

    section_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("sections.id", ondelete="CASCADE"),
        nullable=False,
    )

    academic_year: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    faculty: Mapped["Faculty"] = relationship(
        back_populates="faculty_subjects",
    )

    subject: Mapped["Subject"] = relationship(
        back_populates="faculty_subjects",
    )

    section: Mapped["Section"] = relationship(
        back_populates="faculty_subjects",
    )

    __table_args__ = (
        UniqueConstraint(
            "faculty_id",
            "subject_id",
            "section_id",
            "academic_year",
        ),
    )


# ============================================================
# CLASS SESSIONS
# ============================================================

class ClassSession(Base):
    __tablename__ = "class_sessions"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    faculty_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("faculty.id", ondelete="RESTRICT"),
        nullable=False,
    )

    subject_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("subjects.id", ondelete="RESTRICT"),
        nullable=False,
    )

    section_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("sections.id", ondelete="RESTRICT"),
        nullable=False,
    )

    class_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    hour: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    capture_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    faculty: Mapped["Faculty"] = relationship(
        back_populates="class_sessions",
    )

    subject: Mapped["Subject"] = relationship(
        back_populates="class_sessions",
    )

    section: Mapped["Section"] = relationship(
        back_populates="class_sessions",
    )

    attendance_records: Mapped[list["Attendance"]] = relationship(
        back_populates="class_session",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint(
            "faculty_id",
            "subject_id",
            "section_id",
            "class_date",
            "hour",
        ),
        CheckConstraint(
            "hour BETWEEN 1 AND 10",
        ),
        CheckConstraint(
            "capture_count BETWEEN 0 AND 10",
        ),
    )


# ============================================================
# FACE EMBEDDINGS
# ============================================================

class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    student_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
    )

    embedding: Mapped[list[float]] = mapped_column(
        Vector(512),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    student: Mapped["Student"] = relationship(
        back_populates="face_embeddings",
    )


# ============================================================
# ATTENDANCE
# ============================================================

class Attendance(Base):
    __tablename__ = "attendance"

    id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
    )

    class_session_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("class_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )

    student_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
    )

    confidence: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    marked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    class_session: Mapped["ClassSession"] = relationship(
        back_populates="attendance_records",
    )

    student: Mapped["Student"] = relationship(
        back_populates="attendance_records",
    )

    __table_args__ = (
        UniqueConstraint(
            "class_session_id",
            "student_id",
        ),
    )