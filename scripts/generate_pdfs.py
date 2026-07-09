#!/usr/bin/env python3
"""
Generate PDF CVs from YAML data using ReportLab

Usage:
    python scripts/generate_pdfs.py

Output:
    web/cv/cv_en.pdf
    web/cv/cv_es.pdf
    web/cv/cv_ca.pdf
"""

import os
import yaml
from pathlib import Path
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib import colors
from datetime import datetime

# Directories
PROJECT_ROOT = Path(__file__).parent.parent
CV_DATA_DIR = PROJECT_ROOT / "cv" / "data"
OUTPUT_DIR = PROJECT_ROOT / "web" / "cv"

# Create output directory if it doesn't exist
OUTPUT_DIR.mkdir(exist_ok=True)

# Languages to generate
LANGUAGES = {
    "en": "English",
    "es": "Spanish",
    "ca": "Catalan"
}

def load_cv_data(language: str) -> dict:
    """Load CV data from YAML file"""
    yaml_file = CV_DATA_DIR / f"cv_{language}.yml"

    if not yaml_file.exists():
        raise FileNotFoundError(f"CV data not found: {yaml_file}")

    with open(yaml_file, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def generate_pdf(language: str, cv_data: dict):
    """Generate PDF from CV data using ReportLab"""
    output_file = OUTPUT_DIR / f"cv_{language}.pdf"

    print(f"  Generating {output_file}...")

    try:
        # Create PDF document
        doc = SimpleDocTemplate(str(output_file), pagesize=A4, topMargin=0.5*inch, bottomMargin=0.5*inch)
        story = []
        styles = getSampleStyleSheet()

        # Define custom styles
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#2c3e50'),
            spaceAfter=6,
            alignment=0
        )
        heading_style = ParagraphStyle(
            'CustomHeading',
            parent=styles['Heading2'],
            fontSize=12,
            textColor=colors.HexColor('#2c3e50'),
            spaceAfter=6,
            borderBottom=1,
            borderColor=colors.HexColor('#3498db'),
            borderPadding=3
        )
        normal_style = ParagraphStyle(
            'CustomNormal',
            parent=styles['Normal'],
            fontSize=10,
            textColor=colors.HexColor('#555555')
        )
        meta_style = ParagraphStyle(
            'Meta',
            parent=styles['Normal'],
            fontSize=9,
            textColor=colors.HexColor('#7f8c8d')
        )

        # Header
        personal = cv_data.get('personal', {})
        story.append(Paragraph(personal.get('name', 'CV'), title_style))
        story.append(Paragraph(personal.get('title', ''), meta_style))
        story.append(Spacer(1, 0.1*inch))

        # Summary
        if personal.get('summary'):
            story.append(Paragraph('<b>Summary:</b> ' + personal['summary'], normal_style))
            story.append(Spacer(1, 0.1*inch))

        # Experience
        if cv_data.get('experience'):
            story.append(Paragraph('EXPERIENCE', heading_style))
            for job in cv_data['experience']:
                story.append(Paragraph(f"<b>{job.get('position', '')}</b> @ {job.get('company', '')}", normal_style))
                story.append(Paragraph(f"{job.get('period', '')} | {job.get('location', '')}", meta_style))
                if job.get('achievements'):
                    for achievement in job['achievements']:
                        story.append(Paragraph(f"• {achievement}", normal_style))
                story.append(Spacer(1, 0.08*inch))

        # Education
        if cv_data.get('education'):
            story.append(Paragraph('EDUCATION', heading_style))
            for edu in cv_data['education']:
                story.append(Paragraph(f"<b>{edu.get('degree', '')}</b> - {edu.get('institution', '')}", normal_style))
                story.append(Paragraph(f"{edu.get('period', '')} | {edu.get('location', '')}", meta_style))
                story.append(Spacer(1, 0.08*inch))

        # Skills
        if cv_data.get('skills'):
            story.append(Paragraph('SKILLS', heading_style))
            skills = cv_data['skills']
            if isinstance(skills, dict):
                for category, items in skills.items():
                    if isinstance(items, list):
                        story.append(Paragraph(f"<b>{category.title()}:</b> {', '.join(items)}", normal_style))
            story.append(Spacer(1, 0.08*inch))

        # Languages
        if cv_data.get('languages'):
            story.append(Paragraph('LANGUAGES', heading_style))
            languages = cv_data['languages']
            if isinstance(languages, list):
                for lang_data in languages:
                    if isinstance(lang_data, dict):
                        name = lang_data.get('name', '')
                        level = lang_data.get('level', '')
                        story.append(Paragraph(f"<b>{name}:</b> {level}", normal_style))
                    else:
                        story.append(Paragraph(f"{lang_data}", normal_style))
            elif isinstance(languages, dict):
                for lang, level in languages.items():
                    story.append(Paragraph(f"<b>{lang}:</b> {level}", normal_style))

        # Footer
        story.append(Spacer(1, 0.2*inch))
        story.append(Paragraph(f"Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", meta_style))

        # Build PDF
        doc.build(story)
        file_size = os.path.getsize(output_file) / 1024
        print(f"  [OK] Created: {output_file} ({file_size:.1f} KB)")
        return True
    except Exception as e:
        print(f"  [ERROR] {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print(f"CloudCV PDF Generator (using ReportLab)")
    print(f"Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    success_count = 0

    for lang_code, lang_name in LANGUAGES.items():
        print(f"Processing {lang_name} (cv_{lang_code}.yml):")

        try:
            # Load CV data
            cv_data = load_cv_data(lang_code)

            # Add metadata
            cv_data["language"] = lang_name
            cv_data["generated_date"] = datetime.now().strftime("%B %d, %Y")

            # Generate PDF
            if generate_pdf(lang_code, cv_data):
                success_count += 1

        except Exception as e:
            print(f"  [ERROR] Failed: {e}")
            import traceback
            traceback.print_exc()

        print()

    # Summary
    print(f"Summary: {success_count}/{len(LANGUAGES)} PDFs generated successfully")

    if success_count == len(LANGUAGES):
        print()
        print("Next steps:")
        S3_BUCKET = "example-cloudcv-assets-002645520899"
        print(f"  1. Upload PDFs to S3:")
        print(f"     aws s3 cp web/cv/ s3://{S3_BUCKET}/cv/ --recursive --exclude '*' --include '*.pdf'")
        print(f"  2. Verify upload: aws s3 ls s3://{S3_BUCKET}/cv/")
        return 0
    else:
        return 1

if __name__ == "__main__":
    exit(main())
