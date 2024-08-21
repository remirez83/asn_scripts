#!/bin/bash

#########################################################################
#                                                                       #
#       mail = remigiusz.stojka@atos.net                                #
#       CREATED  = 02/10/2020                                           #
#       MODIFIED = 04/07/2024                                           #
#                                                                       #
#########################################################################

source $HOME/.alias 2>/dev/null
shopt -s expand_aliases 2>/dev/null

getHelp() {
cat << EOF
$(tput bold) NAME
$(tput sgr0) $(printf "\t")$(basename $0) - Simple script to manage ASN IAM daily tasks
$(tput bold) SYNOPSIS
$(tput sgr0) $(printf "\t")$(basename $0) COMMAND [ARGUMENT];
$(tput bold) DESCRIPTION
$(tput sgr0) The scripts depends on several 3rd party programs to collect and/or modify data from saacon store$(printf \t)If COMMAND is specified and ARGUMENT is valid, it allows following operations:
$(tput bold) $(printf "\t")getAssignments$(tput sgr0) $(printf "\t") - Will get you list of current assignments for specified DAS ID ( requirements: 1. starts with letter(s), 2. 7 characters long ).
$(tput bold) $(printf "\t")getAssignmentsHistory$(tput sgr0) $(printf "\t") - Will get list of historical assignments and their status, end date and person responsible for assignment.
$(tput bold) $(printf "\t")getAssignmentsHistory_Full$(tput sgr0) $(printf "\t") - the same as getAssignmentsHistory, only a bit more detailed
$(tput bold) $(printf "\t")removeAssignment$(tput sgr0) $(printf "\t") - Will remove specified role assignment for specified DASID, only if role parameter is empty.
$(tput bold) $(printf "\t")groupMembershipReport$(tput sgr0) $(printf "\t") - Provides you with generic report on members of a certain group(s) and their role assignments.
$(tput bold) EXAMPLES
$(tput sgr0) $(printf "\t")$(basename $0) getAssignments A652833
$(printf "\t")$(basename $0) getAssignmentsHistory A652833
$(printf "\t")$(basename $0) getAssignmentsHistory_Full A652833
$(printf "\t")$(basename $0) removeAssignment A652833 'ManagedServer-(Windows)-2ndLevel-Admin'
$(printf "\t")$(basename $0) groupMembershipReport 'ASN-IAM--SupportSpecialist--3rdL_ASN_IAM_Support'
$(printf "\t")$(basename $0) groupMembershipReport file_with_groups.txt
$(tput bold) AUTHOR
$(tput sgr0) $(printf "\t")remigiusz.stojka@atos.net

EOF
}

getDN() {
d=$(dxim "(dxmGUID=$1)" -b "ou=GCD,cn=Users,$base" dn 2> /dev/null | grep ^dn | /opt/DirX/iddirx/bin/decode64.sh | cut -d' ' -f2-)
if [[ -n "$d" ]]
then
	dien="$d";
else
	printf "\n\nUser not found\n\n";
	exit 1;
fi
}

getAssignments() {
assignments=$(dxim '(objectClass=dxrAssignment)' -b "$dien" dxrAssignTo dxrRoleParamValue 2>/dev/null | /opt/DirX/iddirx/bin/decode64.sh | egrep '^dxrAssignTo|^    <value key=' | sed -e 's/<value key="cn=/<value key="/g' | cut -d'>' -f1 | cut -d',' -f1 | tr -d '\n' | tr '"' '|' | sed -e 's/cn=/\n/g' | sed -e 's/    <value key=//g' -e 's/dxrAssignTo://g' -e 's/||/;/g');
}

findLM() {
manager=$(dxim -b "$dien" manager | grep ^manager | decode64.sh | cut -d' ' -f2- 2> /dev/null)
}

findFM() {
plik1="/tmp/1$RANDOM";
plik2="/tmp/2$RANDOM";
plik3="/tmp/3$RANDOM";
IFS=$'\n'
cat /dev/null > "$plik1";
cat /dev/null > "$plik2";
cat /dev/null > "$plik3";
sien=$(echo $dxrAssignTo | sed -e 's/(/\\(/g' -e 's/)/\\)/g');
dxim "(&(cn=$sien)(objectclass=dxrTargetSystemGroup))" uniqueMember 2>/dev/null | grep ^uniqueMember | /opt/DirX/iddirx/bin/decode64.sh | cut -d' ' -f2- | cut -d'=' -f2 | cut -d',' -f1 > "$plik1";
if [[ "$RoleParam" =~ .*PASSVA*. ]]
then
	dxim "(&(cn=$RoleParam)(objectclass=dxrTargetSystemGroup))" uniqueMember 2>/dev/null | grep ^uniqueMember | /opt/DirX/iddirx/bin/decode64.sh | cut -d' ' -f2- | cut -d'=' -f2 | cut -d',' -f1  > "$plik2";
else
	dxim "(&(cn=$RoleParam)(objectclass=dxrTargetSystemGroup))" owner 2>/dev/null | grep ^owner | /opt/DirX/iddirx/bin/decode64.sh | cut -d' ' -f2- | cut -d'=' -f2 | cut -d',' -f1  > "$plik2";
fi
fgrep -f "$plik2" "$plik1" > "$plik3";
fm=$(for line in $(cat "$plik3"); do printf "$line , "; done);
rm -f $plik1 $plik2 $plik3;


}

getGroupOwner() {
owner=$(for all in $(dxim "(cn=$dxrRoleParamValue)" owner | grep -A2 ^owner | sed -e 's/^ //g' | tr -d '\n' | sed -e 's/owner://g' -e 's/: /\n#/g' -e 's/ cn=/\n/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/; /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/; /g' 2> /dev/null); do if [[ "$all" =~ ^#.* ]]; then echo "$all" | cut -d'#' -f2 | base64 -d | sed -e 's/^cn=//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/; /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/; /g' ; else printf "$all "; fi; done | sed -e 's/search result//g' 2> /dev/null)
}

printAssignments() {
number_of_assignments=$(echo "$assignments" | wc -l)
if [[ "$number_of_assignments" -ge 1 ]]
then
printf "\nFollowing assignments were found for \n\n\t\t";
tput bold;
printf "$(echo $dien | sed -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1//g' -e 's/cn=//g')\n\n#|\t\t\tRole\t\t\t|\tParameter\t\t|\t\tResponsible manager\t\t|\n";
tput sgr0;
for ((i=2;i<=number_of_assignments;i++));
do
assignment=`echo "$assignments" | sed -n "${i}p"`
dxrAssignTo=$(echo "$assignment" | cut -d'|' -f1)
dxrRoleParamValue=$(echo "$assignment" | cut -d'|' -f2 | sed -e 's/;/ ; /g')
IFS=$'\n';
efem_file="/tmp/FM_$RANDOM_$RANDOM";
for RoleParam in $(echo $dxrRoleParamValue | sed -e 's/ ; /\n/g')
do
findFM dxrAssignTo $RoleParam 2>/dev/null;
echo $fm >> $efem_file;
done
efem=$(cat $efem_file | tr '\n' ';' | sed -e 's/, ;/; /g' -e 's/;|/|/g');
rm -f $efem_file;

if [[ $(echo $dxrAssignTo | xargs) = "SAaCon-All-Access" ]] || [[ $(echo $dxrAssignTo | xargs) = "SAaCon-AD-Access" ]] || [[ $(echo $dxrAssignTo | xargs) = "SAaCon-Unix-Access" ]]
then
printf "$(($i-1))|\t$dxrAssignTo\t\t\t|\t\t\t\t|\t$(echo $manager | cut -d',' -f1 | cut -d'=' -f2-)\t\t|\n";
elif [[ "$dxrAssignTo" = "SAaCon-(IAM)-Administrator" ]]
then
printf "$(($i-1))|\t$dxrAssignTo\t\t|\t$dxrRoleParamValue\t|\t$efem\t\t|\n";
else
printf "$(($i-1))|  $dxrAssignTo  |  $dxrRoleParamValue |   $efem|\n";
fi
done
elif [[ "$number_of_assignments" -lt 1 ]]
then
printf "\n\nNo assignments found!\n\n";
fi;
}

printAssignmentHistory_Full() {
IFS=$'\n';
printf "$(tput bold)\n\n# |\t\t\tAssignment\t\t\t|\tEndDate\t\t|    State    |    Approver$(tput sgr0)";
L1=$(for all in $(dxim -b "cn=Assignment Information,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" dxrUserLink dxrState dxrEndDate dxmDisplayName 2> /dev/null | egrep '^dxrUserLink|^dxrState|^dxrEndDate|^dxmDisplayName' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrUserLink: cn=/ | /g' -e 's/dxrState: / | /g' -e 's/dxrEndDate: / | /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1//g'; done)

L2=$(for all in $(dxim -b "cn=Re-Approval by Managers,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do for a in $(dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" 1 2> /dev/null | grep . | cut -d' ' -f2-); do sone=$(dxim -b "${a}" -s base dxmDisplayName dxrEndDate dxrState 2> /dev/null | egrep '^dxmDisplayName|^dxrEndDate|^dxrState' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrEndDate: / | /g' -e 's/dxrState: / | /g'); stwo=$(dxim -b "${a}" '(&(objectclass=dxmIDMActivityInstance)(dxmActivityType=approveAssignment)(cn=Re-Approval by Privilege Manager-0))' dxrUserLink 2> /dev/null | grep ^dxrUserLink | decode64.sh | tr -d '\n' | sed -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central\ndxrUserLink: cn=/,/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1\ndxrUserLink: cn=/,/g'-e 's/dxrUserLink: cn=//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/ ( Re-Approval ) /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/ ( Re-Approval ) /g'); printf "$sone | $stwo"; done; done)

L3=$(for all in $(dxim -b "cn=SOD Approval,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do for a in $(dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" 1 2> /dev/null | grep . | cut -d' ' -f2-); do sone=$(dxim -b "${a}" -s base dxmDisplayName dxrEndDate dxrState 2> /dev/null | egrep '^dxmDisplayName|^dxrEndDate|^dxrState' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrEndDate: / | /g' -e 's/dxrState: / | /g'); stwo=$(dxim -b "${a}" '(&(objectclass=dxmIDMActivityInstance)(dxmActivityType=approveAssignment)(cn=Approval by Topic Manager-0))' dxrUserLink 2> /dev/null | grep ^dxrUserLink | decode64.sh | tr -d '\n' | sed -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central\ndxrUserLink: cn=/,/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1\ndxrUserLink: cn=/,/g'-e 's/dxrUserLink: cn=//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/ ( SoD Approval ) /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/ ( SoD Approval ) /g'); printf "$sone | $stwo"; done; done)

L4=$(for all in $(dxim -b "cn=Re-Approval by Line Manager,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do for a in $(dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" 1 2> /dev/null | grep . | cut -d' ' -f2-); do sone=$(dxim -b "${a}" -s base dxmDisplayName dxrEndDate dxrState 2> /dev/null | egrep '^dxmDisplayName|^dxrEndDate|^dxrState' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrEndDate: / | /g' -e 's/dxrState: / | /g'); stwo=$(dxim -b "${a}" '(&(objectclass=dxmIDMActivityInstance)(dxmActivityType=approveAssignment)(cn=Re-Approval by Line Manager-0))' dxrUserLink 2> /dev/null | grep ^dxrUserLink | decode64.sh | tr -d '\n' | sed -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central\ndxrUserLink: cn=/,/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1\ndxrUserLink: cn=/,/g'-e 's/dxrUserLink: cn=//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/ ( Re-Approval ) /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/ ( Re-Approval ) /g'); printf "$sone | $stwo"; done; done)

L5=$(for all in $(dxim -b "cn=Assignment with SelfassignmentCheck and Approval,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do for a in $(dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do dxim -b "${a}" -s base dxmDisplayName dxrEndDate dxrState dxrUserLink 2> /dev/null | egrep '^dxmDisplayName|^dxrEndDate|^dxrState|^dxrUserLink' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrEndDate: / | /g' -e 's/dxrState: / | /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central\ndxrUserLink: cn=/,/g'  -e 's/dxrState: / | /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1\ndxrUserLink: cn=/,/g'-e 's/dxrUserLink: cn=/ | /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/ ( SelfAssignment Check) /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/ ( SelfAssignment Check) /g'; done; done)

L6=$(for all in $(dxim -b "cn=Re-Approval Project Roles,cn=SAaCON,cn=Monitor,cn=wfRoot,$base" -s one 1 2> /dev/null | grep . | cut -d' ' -f2-); do for a in $(dxim -b "${all}" "(&(objectclass=dxmIDMWorkflowInstance)(dxrSubjectLink=$dien))" 1 2> /dev/null | grep . | cut -d' ' -f2-); do sone=$(dxim -b "${a}" -s base dxmDisplayName dxrEndDate dxrState 2> /dev/null | egrep '^dxmDisplayName|^dxrEndDate|^dxrState' | decode64.sh | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/g' -e 's/dxrEndDate: / | /g' -e 's/dxrState: / | /g'); stwo=$(dxim -b "${a}" '(&(objectclass=dxmIDMActivityInstance)(dxmActivityType=approveAssignment)(cn=Re-Approval Project Roles-0))' dxrUserLink 2> /dev/null | grep ^dxrUserLink | decode64.sh | tr -d '\n' | sed -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central\ndxrUserLink: cn=/,/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1\ndxrUserLink: cn=/,/g' -e 's/dxrUserLink: cn=//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central/ ( Re-Approval ) /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1/ ( Re-Approval ) /g'); printf "$sone | $stwo"; done; done)

list=$(printf "${L1}${L2}${L3}${L4}${L5}${L6}" | sort -k2 -t'|')
for (( i=2;i<=$(echo "${list}" | wc -l);i++ ))
do
if [[ $i -lt 11 ]]
then
printf "\n$((i - 1)) |$(echo "$list" | sed -n "${i}p" )";
else
printf "\n$((i - 1))|$(echo "$list" | sed -n "${i}p" )";
fi
done

printf "\n\n"

}

printAssignmentHistory() {
IFS='';
printf "$(tput bold)\n\n# |\t\t\tAssignment\t\t\t|\tEndDate\t\t|    State    |    Assigned by$(tput sgr0)";

list=$(dxim -b "cn=SAaCON,cn=Monitor,cn=WfRoot,$base" -o ldif-wrap=no "(&(objectClass=dxmIDMWorkflowinstance)(dxrSubjectLink=$dien))" dxmDisplayName dxrState dxrEndDate dxrUserLink 2>/dev/null | decode64.sh | egrep '^dxmDisplayName|^dxrEndDate|^dxrState|^dxrUserLink' | tr -d '\n' | sed -e 's/dxmDisplayName: /\n/'g -e 's/dxrEndDate: /   |   /g' -e 's/dxrState: /   |   /g' -e 's/dxrUserLink: cn=/   |   /g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-Central//g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1//g' -e 's/DomainAdmin/DomainAdmin ( Re-Approval )/g' -e 's/,cn=ASN-IAM-Central//g' -e 's/,cn=ASN-IAM-EMEA1//g'| sort -k2 -t'|');

for (( i=2;i<=$(echo $list | wc -l);i++ ))
do
if [[ $i -lt 11 ]]
then
printf "\n$((i - 1)) |$(echo "$list" | sed -n "${i}p" )";
else
printf "\n$((i - 1))|$(echo "$list" | sed -n "${i}p" )";
fi
done

printf "\n\n"
}

removeAssignment() {
role_=$(dxim -b "cn=RoleCatalogue,$base" "(&(objectclass=dxrRole)(cn=$(echo $2 | sed -e 's/(/\\(/g' -e 's/)/\\)/g')))" 1 | grep . | decode64.sh | cut -d' ' -f2-)
ass=$(dxim -b "$dien" "(&(dxrAssignTo=$role_)(objectClass=dxrAssignment)(\!(dxrRoleParamValue=*)))" dn 2> /dev/null | grep -A1 ^dn | sed -e 's/^ //g' | tr -d '\n' | sed -e 's/--dn: /\n/g' -e 's/dn: /\n/g')
if [ "${#ass}" -lt 1 ]
then
ass=$(dxim -b "$dien" "(&(dxrAssignTo=$role_)(objectClass=dxrAssignment))" dn 2> /dev/null | grep -A1 ^dn | sed -e 's/^ //g' | tr -d '\n' | sed -e 's/--dn: /\n/g' -e 's/dn: /\n/g')
fi
IFS=$'\n'
for all in $ass
do
	dxim_d "$all" 2> /dev/null;
done

printf "dn: $dien\nchangetype: modify\ndelete: dxrRoleLink\ndxrRoleLink: $role_\n-\nreplace: dxrTBA\ndxrTBA: TRUE\n\n" | dxim_m 2>/dev/null;
}

find_ASE() {
IFS=$'\n'
ase_in=$(connectivity -b "$(connectivity '(&(dxmDisplayName=AccountSaveEvent)(objectclass=dxmJob))' dxmInputChannel-DN | grep '^dxmInputChannel-DN' | cut -d' ' -f2-)" dxmSpecificAttributes| egrep 'base_obj|filter')
base_obj=$(echo $ase_in | tr -d '\n' | sed -e 's/dxmSpecificAttributes: /\n/g' | grep ^base_obj | cut -d' ' -f2-)
filter=$(echo $ase_in | tr -d '\n' | sed -e 's/dxmSpecificAttributes: /\n/g' | grep ^filter | cut -d' ' -f2-)
error=$(dxim -b "$base_obj" "$filter" dxrFilter | decode64.sh | grep -i dxrerror | sed -e 's/dxrerror=/^/g' | cut -d'^' -f2- | cut -d')' -f1)
}

remove_NON_Atos_accounts() {
if [[ -d "$HOME/CleanUP" ]]; then dyr="$HOME/CleanUP"; else mkdir "$HOME/CleanUP"; dyr="$HOME/CleanUP"; fi;
dxim -b "cn=TargetSystems,$base" '(&(objectclass=dxrTargetSystemAccount)(gecos=*IAM Managed)(!(cn=c*)))' cn | grep '^cn' | cut -d' ' -f2 | sort -u > "$dyr/TargetSystemAccounts_$(date +%Y%m%d).txt"
dxim -b "ou=GCD,cn=Users,$base" '(objectclass=dxrUser)' dxmGUID | grep ^dxmGUID | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]' > "$dyr/Users_$(date +%Y%m%d).txt"
fgrep -v -f "$dyr/Users_$(date +%Y%m%d).txt" "$dyr/TargetSystemAccounts_$(date +%Y%m%d).txt" > "$dyr/NOT_Working_$(date +%Y%m%d).txt"
dxim -f "$dyr/NOT_Working_$(date +%Y%m%d).txt" -b "cn=TargetSystems,$base" '(&(objectclass=dxrTargetSystemAccount)(gecos=*IAM Managed)(cn=%s))' 1 | grep . | split -l 2000 - "$dyr/For_Removal_$(date +%Y%m%d)_"
for file in `ls $dyr/For_Removal_$(date +%Y%m%d)_*`; do IFS=$'\n'; for all in $(cat $file); do printf "$all\nchangetype: modify\nreplace: dxrError\ndxrError: $error\n-\nreplace: dxrState\ndxrState: DELETED\n-\nreplace: dxrTSLocal\ndxrTSLocal: FALSE\n-\nreplace: dxrEndDate\ndxrEndDate: 20210701230000Z\n\n" >> "$file.ldif"; done; done
}

remove_NO_role_Accounts() {
if [[ -d "$HOME/CleanUP" ]]; then dyr="$HOME/CleanUP"; else mkdir "$HOME/CleanUP"; dyr="$HOME/CleanUP"; fi;
dxim -b "ou=gcd,cn=users,$base" '(&(objectclass=dxrUser)(!(dxrRoleLink=*)))' dxmGUID | grep ^dxmGUID | cut -d' ' -f2 > "$dyr/Users_without_role_$(date +%Y%m%d).txt"
IFS=$'\n'; for all in $(dxim -b "cn=TargetSystems,$base" -f "$dyr/Users_without_role_$(date +%Y%m%d).txt" '(&(cn=%s)(gecos=*IAM Managed))' 1 | decode64.sh | grep .); do printf "$all\nchangetype: modify\nreplace: dxrError\ndxrError: $error\n-\nreplace: dxrState\ndxrState: DELETED\n-\nreplace: dxrTSLocal\ndxrTSLocal: FALSE\n-\nreplace: dxrEndDate\ndxrEndDate: 20210701230000Z\n\n"; done | dxim_m
}

groupMembershipReport() {
IFS=$'\n'
for group in $(dxim "(&(objectclass=dxrTargetSystemGroup)(cn=$1))" dxrRPValues | egrep '^dn|^dxrRPValues' | decode64.sh | tr -d '\n' | sed -e 's/dn: /\n/g' -e 's/dxrRPValues: myrpwhere=cn/ | /g' -e 's/dxrRPValues: dn/ | /g' -e 's/(/\\(/g' -e 's/)/\\)/g' -e 's/&/*/g')
do
	for perm in $(dxim "(&(objectclass=dxrPermission)(dxrGroupLink=$group))" 1 | grep . | decode64.sh | cut -d' ' -f2- | sed -e 's/(/\\(/g' -e 's/)/\\)/g')
	do
		for dxrAssignTo in $(dxim "(&(objectclass=dxrRole)(dxrPermissionLink=$perm))" cn | grep ^cn | decode64.sh | cut -d' ' -f2- | sort -u)
		do
			for RoleParam in $(echo $group | cut -d'|' -f2- | tr '|' '\n' | cut -d'=' -f2- | cut -d',' -f1)
			do
				for a in $(dxim -b "ou=gcd,cn=users,$base" "(&(objectclass=dxrAssignment)(dxrAssignTo=*$(echo $dxrAssignTo | sed -e 's/(/\\(/g' -e 's/)/\\)/g')*)(dxrRoleParamValue=*$RoleParam*))" dxrAssignFrom dxrEndDate dxrState | egrep '^dxrAssignFrom|^dxrEndDate|^dxrState' | decode64.sh | tr -d '\n' | sed -e 's/dxrAssignFrom: cn=/\n/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-CentraldxrEndDate: / | /g' -e 's/dxrAssignFrom: cn=/\n/g' -e 's/,ou=GCD,cn=Users,cn=ASN-IAM-EMEA1dxrEndDate: / | /g'-e 's/ZdxrState: / | /g')
				do
					findFM $dxrAssignTo $RoleParam 2>/dev/null
					printf "\n$group | $dxrAssignTo | $RoleParam | $(echo $fm | tr '\n' ';' | sed -e 's/, ;/; /g' -e 's/;|/|/g') | $a\n"

				done
			done
		done
	done
done

}

whatProvides(){
if [[ "$(echo "$1" | wc -m)" -gt 2 ]]
then
#	IFS=''
#	ts=$(dxim -b "cn=TargetSystems,$base" "(&(objectclass=dxrTargetSystem)(|(cn=$1)(description=*$1*)(dxmAddress=$1)(displayName=*$1*)))" dn | grep ^dn | grep -v 'cn=CCinfo-Light,cn=Cluster Container AdminArea' | cut -d' ' -f2-)
if [[ "$1" =~ [0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3} ]] && [[ ! "$1" =~ ^SNC ]]
then
	IFS=''
	ts=$(dxim -b "cn=TargetSystems,$base" "(&(objectclass=dxrTargetSystem)(|(description=*$1*)(dxmAddress=$1)))" dn | grep ^dn | grep -v 'cn=CCinfo-Light,cn=Cluster Container AdminArea' | cut -d' ' -f2-)
elif [[ "$1" =~ ^'cn=' ]] && [[ "$1" =~ ",cn=TargetSystems,$base"$ ]]
then
	IFS=''
	ts=$(dxim -b "$1" '(&(objectclass=dxrTargetSystem)(dxrState=ENABLED))' dn | grep ^dn | cut -d' ' -f2-)
else
	IFS=''
	ts=$(dxim -b "cn=TargetSystems,$base" "(&(objectclass=dxrTargetSystem)(|(cn=$1)(description=*$1*)(dxmSpecificAttributes=Customer*$1*)(displayName=*$1*)))" dn | grep ^dn | grep -v 'cn=CCinfo-Light,cn=Cluster Container AdminArea' | cut -d' ' -f2-)
fi
fi
if [[ "$(echo "$ts" | wc -l)" -eq 1 ]]
then
		IFS=$'\n';
		for all in $(dxim -b "cn=Groups,$ts" -s one '(&(objectclass=dxrTargetSystemGroup)(dxrState=ENABLED)(dxrTSState=ENABLED)(dxrRPValues=*))' dxrRPValues | tr -d '\n' | sed -e 's/dn: /\n/g' -e 's/dxrRPValues: myrpwhere=/ | /g' -e 's/dn=/ | /g')
		do
                        for perm in $(dxim "(&(objectclass=dxrPermission)(dxrGroupLink=$(echo $all | cut -d'|' -f1 | xargs | sed -e 's/(/\\(/g' -e 's/)/\\)/g')))" dn | grep ^dn | cut -d' ' -f2- | sed -e 's/(/\\(/g' -e 's/)/\\)/g')
			do
				for dxrAssignTo in $(dxim "(&(objectclass=dxrRole)(dxrPermissionLink=$perm))" cn | grep ^cn | cut -d' ' -f2- | sort -u)
				do
					for RoleParam in $(echo $all | cut -d'|' -f2- | tr '|' '\n' | cut -d'=' -f2 | cut -d',' -f1 )
                        		do
						if [[ "$(echo $dxrAssignTo | wc -m)" -gt 1 ]]
                        			then
							if [[ "$(echo $RoleParam | xargs)" != "*" ]]
							then
                                				findFM $dxrAssignTo $RoleParam 2>/dev/null
                                				printf "$dxrAssignTo | $RoleParam | $(echo $fm | tr '\n' ';' | sed -e 's/, ;/; /g' -e 's/;|/|/g')\n"
                        				else
								printf "$dxrAssignTo | $(echo $RoleParam | xargs) | $(dxim "(&(objectclass=dxrTargetSystemGroup)(cn=$(echo $dxrAssignTo | sed -e 's/(/\\(/g' -e 's/)/\\)/g')))" uniqueMember | grep ^uniqueMember | /opt/DirX/iddirx/bin/decode64.sh | cut -d'=' -f2- | cut -d',' -f1 | grep -v 'ASN-IAM-Central' | tr '\n' ',' | sed -e 's/,/ , /g')\n"
							fi
						fi
					done
				done
                	done
		done

elif [[ "$(echo -n "$ts" | wc -l)" -lt 1 ]]
then
	printf "\nERROR -> TargetSystem $1 NOT FOUND\n\n"
	exit
else
	printf "\nERROR -> Multiple TargetSystems found by $1 name. Please specify one from below list\n\n$(printf $ts)\n\n"
	exit
fi

}


if [[ "$(grep $(hostname) /etc/hosts | grep -v '#' | cut -d' ' -f4)" =~ .*central.* ]]; then base="cn=ASN-IAM-Central"; else base="cn=ASN-IAM-EMEA1"; fi

if [[ "$1" == "getAssignments" ]] && [[ `echo "$2" | tr '[:upper:]' '[:lower:]'` = [a-z]* ]] && [[ "${#2}" -eq 7 ]]
then
shift;
getDN $@ 2> /dev/null;
findLM 2>/dev/null;
getAssignments 2> /dev/null;
printAssignments 2> /dev/null;
echo;

elif [[ "$1" == "getAssignmentsHistory" ]] && [[ `echo "$2" | tr '[:upper:]' '[:lower:]'` = [a-z]* ]] && [[ "${#2}" -eq 7 ]]
then
shift;
getDN $@ 2> /dev/null;
printAssignmentHistory 2>/dev/null;

elif [[ "$1" == "removeAssignment" ]] && [[ `echo "$2" | tr '[:upper:]' '[:lower:]'` = [a-z]* ]] && [[ "${#2}" -eq 7 ]] && [[ "$#" -eq 3 ]]
then
shift;
getDN $@ 2> /dev/null;
removeAssignment $@ 2> /dev/null;

elif [[ "$1" == "getAssignmentsHistory_Full" ]] && [[ `echo "$2" | tr '[:upper:]' '[:lower:]'` = [a-z]* ]] && [[ "${#2}" -eq 7 ]]
then
shift;
getDN $@ 2> /dev/null;
printAssignmentHistory_Full 2>/dev/null;

elif [[ "$1" == "whatProvides" ]] && [[ "$#" -eq 2 ]]
then
shift;
printf "\nRole | Parameter | Functional Manager(s)\n";
whatProvides "$@" 2>/dev/null;
echo;
elif [[ "$1" == "groupMembershipReport" ]] && [[ "$#" -eq 2 ]]
then
	if [[ -f "$2" ]]
	then
		printf "\nGROUP | ROLE | PARAMETER | FUNCTIONAL MANAGER(s) | USER | END DATE | STATE\n";
		IFS=$'\n'
		for all in $(cat $2)
		do
			groupMembershipReport $all 2>/dev/null;
		done
		echo; echo;
	else
		shift;
		printf "\nGROUP | ROLE | PARAMETER | FUNCTIONAL MANAGER(s) | USER | END DATE | STATE\n";
		groupMembershipReport "$1" 2> /dev/null;
		echo; echo;
	fi;
else
getHelp;
fi;

