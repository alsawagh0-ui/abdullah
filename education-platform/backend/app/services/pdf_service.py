import fitz  # PyMuPDF


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """يستخلص النص الكامل من ملف PDF (كتاب/درس إلكتروني)."""
    doc = fitz.open(stream=file_bytes, filetype="pdf")
    pages_text = [page.get_text() for page in doc]
    doc.close()
    return "\n\n".join(pages_text)
