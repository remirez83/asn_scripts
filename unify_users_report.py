#!/usr/bin/python3.6

#########################################################################
#                                                                       #
#       mail = remigiusz.stojka@atos.net                                #
#       CREATED  = 07/06/2022                                           #
#       MODIFIED = 07/06/2022                                           #
#                                                                       #
#########################################################################


from openpyxl import load_workbook
import csv

rows = []
wb = load_workbook('/opt/DirX/iddirx/bin/maintScripts/reports/UnifyReport_template.xlsx')
ws = wb["Tabelle1"]
ws._pivots[0].cache.refreshOnLoad = True
with open('/opt/DirX/iddirx/bin/maintScripts/reports/unify_users_with_roles.csv', newline='') as csvfile:
        plik = csv.reader(csvfile, delimiter=';')
        for row in plik:
                rows.append(row)

for i in range(1,len(rows)):
        ws.append(rows[i])

wb.save('/opt/DirX/iddirx/bin/maintScripts/reports/UnifyReport.xlsx')
