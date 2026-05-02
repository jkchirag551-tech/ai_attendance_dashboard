from io import BytesIO
from xml.sax.saxutils import escape


def build_attendance_excel(rows, title):
    output = BytesIO()
    safe_title = escape(title)

    xml_parts = [
        '<?xml version="1.0"?>',
        '<?mso-application progid="Excel.Sheet"?>',
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"',
        ' xmlns:o="urn:schemas-microsoft-com:office:office"',
        ' xmlns:x="urn:schemas-microsoft-com:office:excel"',
        ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
        ' <Styles>',
        '  <Style ss:ID="title">',
        '   <Font ss:Bold="1" ss:Size="14"/>',
        '   <Alignment ss:Horizontal="Center"/>',
        '  </Style>',
        '  <Style ss:ID="header">',
        '   <Font ss:Bold="1"/>',
        '   <Borders>',
        '    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>',
        '   </Borders>',
        '   <Interior ss:Color="#E1ECF4" ss:Pattern="Solid"/>',
        '  </Style>',
        ' </Styles>',
        ' <Worksheet ss:Name="Attendance">',
        '  <Table>',
        '   <Column ss:Width="150"/>',
        '   <Column ss:Width="80"/>',
        '   <Column ss:Width="80"/>',
        '   <Column ss:Width="80"/>',
        '   <Column ss:Width="80"/>',
        '   <Column ss:Width="80"/>',
        '   <Row ss:Height="25">',
        f'    <Cell ss:StyleID="title" ss:MergeAcross="5"><Data ss:Type="String">{safe_title}</Data></Cell>',
        '   </Row>',
        '   <Row ss:Height="20">',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Name</Data></Cell>',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Roll Number</Data></Cell>',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Date</Data></Cell>',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Time</Data></Cell>',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Percentage</Data></Cell>',
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Status</Data></Cell>',
        '   </Row>',
    ]

    for row in rows:
        xml_parts.extend(
            [
                '   <Row>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["fullname"]))}</Data></Cell>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["roll_number"]))}</Data></Cell>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["date"]))}</Data></Cell>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["time"]))}</Data></Cell>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["match_score"]))}</Data></Cell>',
                f'    <Cell><Data ss:Type="String">{escape(str(row["status"]))}</Data></Cell>',
                '   </Row>',
            ]
        )

    xml_parts.extend(['  </Table>', ' </Worksheet>', '</Workbook>'])
    output.write('\n'.join(xml_parts).encode('utf-8'))
    output.seek(0)
    return output


def _escape_pdf_text(value):
    return str(value).replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def _format_pdf_cell(value, max_chars):
    text = str(value)
    if len(text) <= max_chars:
        return text
    return f'{text[:max_chars - 3]}...'


def _fit_pdf_text(value, width, font_size, padding=6):
    text = str(value)
    usable_width = max(0, width - (padding * 2))
    if not text or usable_width <= 0:
        return ''

    # Helvetica's average character width is roughly half the font size.
    approx_char_width = max(font_size * 0.52, 1)
    max_chars = max(1, int(usable_width / approx_char_width))
    return _format_pdf_cell(text, max_chars)


def _append_pdf_text(content_lines, text, x, y, font='F1', font_size=9):
    content_lines.extend(
        [
            '0 0 0 rg',
            'BT',
            f'/{font} {font_size} Tf 1 0 0 1 {x} {y} Tm ({_escape_pdf_text(text)}) Tj',
            'ET',
        ]
    )


def build_attendance_pdf(rows, title):
    page_width = 612
    page_height = 792
    margin = 40
    table_width = page_width - (margin * 2)
    title_y = page_height - 40
    subtitle_y = page_height - 60
    table_top = page_height - 100
    row_height = 24
    header_height = 30
    footer_space = 40

    columns = [
        ('Name', 160, 'fullname', 'left'),
        ('Roll Number', 85, 'roll_number', 'left'),
        ('Date', 85, 'date', 'center'),
        ('Time', 75, 'time', 'center'),
        ('Percentage', 72, 'match_score', 'center'),
        ('Status', 55, 'status', 'center'),
    ]
    rows_per_page = max(1, int((table_top - margin - footer_space - header_height) / row_height))
    pages = [rows[i:i + rows_per_page] for i in range(0, len(rows), rows_per_page)] or [[]]

    objects = []

    def add_object(content):
        objects.append(content)
        return len(objects)

    font_id = add_object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    bold_font_id = add_object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>')
    page_ids = []

    for page_index, page_rows in enumerate(pages, start=1):
        content_lines = [
            '0.15 w',
            '0 0 0 RG',
            '0 0 0 rg',
        ]
        _append_pdf_text(content_lines, title, margin, title_y, font='F2', font_size=16)
        _append_pdf_text(content_lines, 'Detailed Attendance Records', margin, subtitle_y, font='F1', font_size=11)
        _append_pdf_text(content_lines, f'Page {page_index}', page_width - margin - 50, title_y, font='F1', font_size=10)

        current_y = table_top
        x = margin

        # Draw Header Row background and text
        for header, width, _, alignment in columns:
            # Set fill color for header background (Light blue)
            content_lines.append('0.85 0.92 1 rg')
            content_lines.append('0 0 0 RG') # Black stroke
            content_lines.append(f'{x} {current_y - header_height} {width} {header_height} re B')

            # Determine text position
            if alignment == 'center':
                approx_text_width = len(header) * 10 * 0.52
                text_x = x + (width - approx_text_width) / 2
            else:
                text_x = x + 6

            # _append_pdf_text sets color to black (0 0 0 rg) internally
            _append_pdf_text(content_lines, header, text_x, current_y - (header_height/2) - 3, font='F2', font_size=10)
            x += width

        current_y -= header_height

        if not page_rows and page_index == 1:
            content_lines.append(f'{margin} {current_y - row_height} {table_width} {row_height} re S')
            _append_pdf_text(content_lines, 'No attendance records available.', margin + 6, current_y - 16, font_size=10)
        else:
            for row_index, row in enumerate(page_rows):
                x = margin
                fill_color = '0.985 0.99 1 rg' if row_index % 2 == 0 else '1 1 1 rg'
                for _, width, key, alignment in columns:
                    content_lines.append(fill_color)
                    content_lines.append(f'{x} {current_y - row_height} {width} {row_height} re B')
                    text = _fit_pdf_text(row[key], width, 9)
                    if alignment == 'center':
                        approx_text_width = len(text) * 9 * 0.52
                        text_x = x + max(6, (width - approx_text_width) / 2)
                    else:
                        text_x = x + 4
                    _append_pdf_text(content_lines, text, text_x, current_y - 16, font_size=9)
                    x += width
                current_y -= row_height

        stream = '\n'.join(content_lines).encode('latin-1', errors='replace')
        content_id = add_object(f'<< /Length {len(stream)} >>\nstream\n{stream.decode("latin-1")}\nendstream')
        page_id = add_object(
            f'<< /Type /Page /Parent 0 0 R /MediaBox [0 0 {page_width} {page_height}] '
            f'/Contents {content_id} 0 R /Resources << /Font << /F1 {font_id} 0 R /F2 {bold_font_id} 0 R >> >> >>'
        )
        page_ids.append(page_id)

    kids = ' '.join(f'{page_id} 0 R' for page_id in page_ids)
    pages_id = add_object(f'<< /Type /Pages /Count {len(page_ids)} /Kids [{kids}] >>')
    catalog_id = add_object(f'<< /Type /Catalog /Pages {pages_id} 0 R >>')

    for page_id in page_ids:
        objects[page_id - 1] = objects[page_id - 1].replace('/Parent 0 0 R', f'/Parent {pages_id} 0 R')

    pdf = bytearray(b'%PDF-1.4\n')
    offsets = [0]

    for index, content in enumerate(objects, start=1):
        offsets.append(len(pdf))
        pdf.extend(f'{index} 0 obj\n{content}\nendobj\n'.encode('latin-1'))

    xref_offset = len(pdf)
    pdf.extend(f'xref\n0 {len(objects) + 1}\n'.encode('latin-1'))
    pdf.extend(b'0000000000 65535 f \n')
    for offset in offsets[1:]:
        pdf.extend(f'{offset:010d} 00000 n \n'.encode('latin-1'))

    pdf.extend(
        (
            f'trailer\n<< /Size {len(objects) + 1} /Root {catalog_id} 0 R >>\n'
            f'startxref\n{xref_offset}\n%%EOF'
        ).encode('latin-1')
    )

    output = BytesIO(pdf)
    output.seek(0)
    return output
