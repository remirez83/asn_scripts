#!/usr/bin/python3.6

#########################################################################
#                                                                       #
#       mail = remigiusz.stojka@eviden.com                              #
#       CREATED  = 19/08/2024                                           #
#       MODIFIED = 19/08/2024                                           #
#                                                                       #
#########################################################################


from datetime import date
import sys, os, argparse, csv, openpyxl

rows = []
d = '{0}{1}{2}{3}{5}{6}{8}{9}'.format(*str(date.today()))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--infile", help="Specify input text file")
    parser.add_argument("-o", "--outfile", help="Specify output XLSX filename")
    parser.add_argument("-s", "--sheet", help="Specify sheet name to write to")
    parser.add_argument("-f", "--separator", help="Specify field separator other than semicolon")
    argu = parser.parse_args()

    if argu.outfile:
        fn = str(argu.outfile)
    else:
        fn = d + ".xlsx"

    if argu.sheet:
        sn = str(argu.sheet)
    else:
        sn=d

    if argu.separator:
        sep = str(argu.separator)
    else:
        sep = ';'

    if argu.infile:
        if os.path.exists(argu.infile):
            wb = openpyxl.Workbook()
            ws = wb.active
            ws.title = str(sn)
            with open(argu.infile, newline='') as csvfile:
                plik = csv.reader(csvfile, delimiter=sep)
                for row in plik:
                    rows.append(row)
				
                for i in range(0,len(rows)):
                    ws.append(rows[i])

                tab = openpyxl.worksheet.table.Table(displayName="Table1", ref=ws.dimensions)
                style = openpyxl.worksheet.table.TableStyleInfo(name="TableStyleMedium2", showRowStripes=True, showColumnStripes=True)
                tab.tableStyleInfo = style
                ws.add_table(tab)
                for i in range(1, ws.max_column + 1):
                    ws.column_dimensions[openpyxl.utils.cell.get_column_letter(i)].width = (len(str(ws.cell(row = 2, column = i).value)) + 2) * 1.2

                wb.save(fn)
