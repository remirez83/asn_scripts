#!/bin/bash

#########################################################################
#                                                                       #
#       mail = remigiusz.stojka@atos.net                                #
#       CREATED  = 07/12/2021                                           #
#       MODIFIED = 12/01/2023                                           #
#       VERSION = 2.0                                                   #
#                                                                       #
#########################################################################

d='saacon';
logfile='ggc.log';
type_=0;

source /opt/DirX/iddirx/.alias 2>/dev/null
shopt -s expand_aliases 2>/dev/null

print_to_log(){
        printf "$(date '+%Y/%m/%d %H:%M') => $1\n"
}

gen_group_name(){
if [[ -z "${gn}" ]] && [[ -n "$permission" ]] && [[ -n "$parameter" ]]
then
        p=$(echo $permission | sed -e 's/(//g' -e 's/)//g');
        gn="ASN-IAM--${p:0:36}--${parameter:0:17}";
                printf "\n\nGroup Name was not deliberately specified with '-n' option, thus I have generated the name for you. Is below name ok?:\n\n\t$gn\n\n\n\t\t\t\t[ YES | NO ] / [ Y | N ]\t";
                read answer;
                printf "\n\n";
                if [[ `echo $answer | tr '[:upper:]' '[:lower:]'` == "y" ]] || [[ `echo $answer | tr '[:upper:]' '[:lower:]'` == "yes" ]]; then
                        group_name=$gn;
                else
                        printf "OK then, please re-run the script and specify Group Name yourself with '-n' option\n\n";
                        print_to_log "ERR: RC 13 - Auto-Generated Group name - $gn was not accepted by the user" | tee -a $logfile;
                        exit 1;
                fi;
elif [[ -n "$gn" ]] && [[ -n "$permission" ]] && [[ -n "$parameter" ]] && [[ "$(echo $gn | wc -c)" -le 64 ]]
then
                group_name=$gn;
elif [[ -n "$gn" ]] && [[ -n "$permission" ]] && [[ -n "$parameter" ]]
then
        print_to_log "ERR: RC 1 - Group name - $gn is too long or incorrect" | tee -a $logfile;
        exit 1;
fi
}

gen_dien(){
dien="cn=${group_name},$group_base"
if [[ $(dxim -b "$dien" -s base 1 | grep ^dn | wc -l) -eq 0 ]]
then
        primarykey="cn=${group_name},$pk_group_base"
else
        print_to_log "ERR: RC 2 - Group: $gn in Domain: $domina exists" | tee -a $logfile;
        exit 2;
fi;

}

gen_standard_group(){
#clear;
ldif="dn: ${dien}\nobjectClass: dxmADsGroup\nobjectClass: dxrTargetSystemGroup\nobjectClass: top\nobjectClass: groupOfUniqueNames\ncn: $group_name\ndescription: $description\nuniqueMember: cn=ASN-IAM-Central\ndxmADsSamAccountName: $group_name\ndxmADsGroupType: global\ndxrPrimaryKey: $primarykey\ndxrRPValues: $(if [[ "$type_" -eq 0 ]]; then echo -n "myrpwhere=$param_dn\n"; else echo -n "dn=$param_dn\n"; fi)dxrState: ENABLED\ndxrTBA: FALSE\ndxrTSLocal: FALSE\ndxrToDo: sync\ndxrTSState: NONE\ndxrUserAssignmentPossible: TRUE\ndxrVersion: 1.0\ndxrName: ${group_name}$(if [[ -n $obligation ]]; then echo -n "\ndxrObligationLink: $obligation\n"; else echo -n "\n"; fi)dxrApprovalPeriod: P0Y0M0DT0H0M0S\ndxrReapprovalPeriod: P0Y0M0DT0H0M0S\ndxrCertificationPeriod: P0Y0M0DT0H0M0S";
}

get_user_id(){
user_ajdi=$(grep "^$(logname)" /etc/passwd | cut -d':' -f5 | sed -e 's/ IAM Managed//g');
if [[ "$(echo "$user_ajdi" | tr '[:upper:]' '[:lower:]')" == "iddirx" ]] || [[ "$(echo "$user_ajdi" | tr '[:upper:]' '[:lower:]')" == "spdirx" ]] || [[ "$(echo "$user_ajdi" | tr '[:upper:]' '[:lower:]')" == "root" ]] || [[ "$(echo "$user_ajdi" | tr '[:upper:]' '[:lower:]')" == "nobody" ]] || [[ "$(echo "$user_ajdi" | tr '[:upper:]' '[:lower:]')" == "test" ]] || [[ $(grep "^$(logname)" /etc/passwd | cut -d':' -f3) -lt 50000 ]]
then
        print_to_log "ERR: RC 4 - Script can't be run as $user_ajdi, please run it from your personal account" | tee -a $logfile;
        exit 4
fi
}

get_permission_dn(){
if [[ -n "$permission" ]]
then
        perm_dn=$(dxim -b 'cn=Permissions,cn=ASN-IAM-Central' "(&(objectclass=dxrPermission)(cn=$(echo $permission | sed -e 's/(/\\(/g' -e 's/)/\\)/g')))" 1 | head -1 | cut -d' ' -f2-);
fi

if [[ -z "${perm_dn}" ]]
then
        printf "\n$perm_dn\n";
        print_to_log "ERR: RC 6 - Role's permission - $permission , not found" | tee -a $logfile;
        exit 6;
fi
}

update_permission(){
printf "dn: $perm_dn\nchangetype: modify\nadd: dxrGroupLink\ndxrGroupLink: $dien\n\n" | dxim_m;
}

get_requester(){
if [[ -n "$who_" ]] && [[ $(echo "$who_" | tr '[:lower:]' '[:upper:]') =~ [A-Z]{1,2}[0-9]{5,6} ]]
then
        requester=$(dxim -b 'ou=GCD,cn=Users,cn=ASN-IAM-Central' "(dxmGUID=$who_)" cn | grep ^cn | /opt/DirX/iddirx/bin/decode64.sh | cut -d' ' -f2-);
fi

if [[ -z "${requester}" ]]
then
        print_to_log "ERR: RC 7 - Requester doesn't seem to be correct" | tee -a $logfile;
        exit 7;
fi
}

get_parameter_dn(){
if [[ -n "$parameter" ]]
then
        param_dn=$(dxim -b 'cn=TargetSystems,cn=ASN-IAM-Central' "(&(objectclass=dxrTargetSystemGroup)(cn=$parameter)(!(dxmADsGroupType=*)))" 1 | head -1 | cut -d' ' -f2-);
fi

if [[ -z "${param_dn}" ]]
then
        print_to_log "ERR: RC 5 - Support group - $parameter , not found" | tee -a $logfile;
        exit 5;
fi
}

get_domain(){
if [[ -n "$d" ]]
then
        domain=$(echo $d | tr '[:upper:]' '[:lower:]');
        domina="$(echo ${domains[$domain]} | cut -d'|' -f1)";
        group_base="$(echo ${domains[$domain]} | cut -d'|' -f3)";
        pk_group_base="$(echo ${domains[$domain]} | cut -d'|' -f2)";
fi
}

get_ticket(){
if [[ "${#t}" -ge 12 && "${#t}" -le 14 && $t =~ ^(INC0|CTASK0|CHG0|TASK0)* ]]
then
        ticket=$t;
else
        print_to_log "ERR: RC 8 - Please check the ticket number again." | tee -a $logfile;
        exit 8;
fi
}

get_obligation(){
if [[ -n $o ]]
then
        obligation="$(echo ${obligations[$o]} | cut -d'|' -f2 | xargs)";
fi
}

get_help(){
cat << EOF

$(tput bold)NAME
$(tput sgr0)$(printf "\t")$(basename "$0") - Create Global ( Active Directory ) Groups easily.

$(tput bold)SYNOPSIS$(tput sgr0)
$(printf "\t")$(basename "$0") [OPTION] [ARGUMENT]

$(tput bold)DESCRIPTION$(tput sgr0)
$(printf "\t")The script depends on several 3rd party programs to collect and/or modify data from saacon store.
$(printf "\t")If OPTIONs are specified and ARGUMENTs are valid, it creates a global group in ASN IAM, which can be further synchronized to destination ADS either manually from DirX Identity or automatically by schedulled DirX Workflow.
$(printf "\t")In order to create desired group, the script has to be run with REQUIRED OPTIONs and/or can be run with VOLUNTARY OPTIONs

$(tput bold)USAGE$(tput sgr0)
$(printf "\t")$(basename "$0") -r <permission> -s <parameter> -o <description> -t <ticket> -w <requester> -n [<name>] -d [<domain>] -x [<0|1>] -b [<obligation>]

$(tput bold)REQUIRED OPTIONs
$(printf "\t")-t$(tput sgr0) - SNOWs ticket number, usually starts with TASK, CTASK, CHG or INC, ie. 'TASK012163712' or 'CHG001514166'.
$(tput bold)$(printf "\t")-s$(tput sgr0) - Parameter of the group, also known as Support Group, ie. 'US.Database.SqlServer' or 'DE.Network.SAaCon.IAM'.
$(tput bold)$(printf "\t")-r$(tput sgr0) - Role that is to be connected with the group by its permission, ie. 'NetworkServices-(All)-NetworkEngineer' or 'Project-Organisation-Member'.
$(tput bold)$(printf "\t")-o$(tput sgr0) - Description of the group usually taken from the ticket.
$(tput bold)$(printf "\t")-w$(tput sgr0) - DAS ID of the requester, ie. A627770

$(tput bold)VOLUNTARY OPTIONs
$(printf "\t")-n$(tput sgr0) - Name of the group ( group's CN ). If specified, has to start with "ASN-IAM--" and be not longer than 63 characters.
$(printf "\t")     If not specified, the script will try to generate a name that fits those requirements itself and will ask for your approval.
$(tput bold)$(printf "\t")-d$(tput sgr0) - Domain of the ADS, where the group should be synchronized to. If omitted, it defaults to "Saacon.net". If specified, can be one of below:
$(for klucz in "${!domains[@]}"; do printf "%30s'$(echo ${klucz} | tr '[:upper:]' '[:lower:]')'|$(echo ${domains[$klucz]} | cut -d'|' -f1)\n"; done | column -t -s'|' -o' - ' | sort -u)
$(tput bold)$(printf "\t")-x$(tput sgr0) - Specify group's type, '0' - Standard Global Group ( default ), '1' -  TeamSafe
$(tput bold)$(printf "\t")-b$(tput sgr0) - Obligation, one of below:
$(for klucz in "${!obligations[@]}"; do printf "%30s'$(echo ${klucz} | tr '[:upper:]' '[:lower:]')'|$(echo ${obligations[$klucz]} | cut -d'|' -f1)\n"; done | column -t -s'|' -o' - ' | sort -u)

$(tput bold)EXAMPLES
$(printf "\t")1.$(tput sgr0) $(tput smul)Create Standard GGC group with specific group name and with cyberarkumbrella obligation$(tput sgr0)

$(printf "\t\t")ggc.sh -t 'TASK013024678' -s 'HU.Application.PIAM' -r 'ASN-(PIAM)-PIAMC_DevOps' -o 'AD group that grants CyberArk safe access and usage of safe content for   Support group(s): HU.Application.PIAM  Support level: L2  Type: PIAM Service  Customer:  AtosASNAdmGates' -w 'A474396' -n 'ASN-IAM--CyberArk_C9_PIAM_L2_1' -b 'cyberarkumbrella'

$(printf "\t")$(tput bold)2.$(tput sgr0) $(tput smul)Create TeamSafe with specific name, parameter, role and obligation$(tput sgr0)

$(printf "\t\t")ggc.sh -t 'TASK013113191' -w 'A861699' -d 'saacon' -b 'cyberarkumbrella' -r 'Project-Organisation-Member' -s 'TS_GEN_PASSVA101102022_RO' -o 'MySQL and PostgreSQL  Databases management for Philips Customer' -n 'ASN-IAM--CyberArk_TS_GEN_PASSVA101102022_RO' -x 1

$(printf "\t")and

$(printf "\t\t")ggc.sh -t 'TASK013113191' -w 'A861699' -d 'saacon' -b 'cyberarkumbrella' -r 'Project-Organisation-Member' -s 'TS_GEN_PASSVA101102022_RW' -o 'MySQL and PostgreSQL  Databases management for Philips Customer' -n 'ASN-IAM--CyberArk_TS_GEN_PASSVA101102022_RW' -x 1

$(printf "\t")$(tput bold)3. $(tput sgr0) $(tput smul)Create Standard GGC group with no obligation and no specific group name$(tput sgr0)

$(printf "\t\t")ggc.sh -t 'CHG001736585' -s 'APPL-ASNSSLVPN-NARSWartung' -r 'ASN-(SSLVPN)-ApplicationUser' -o 'ASN IAM APPL ASNSSLVPN NARSWartung' -w 'A411692'

$(tput bold)AUTHOR$(tput sgr0)
$(printf "\t")<remigiusz.stojka@atos.net>


EOF
}

upgrade(){
if [[ -e /opt/DirX/iddirx/bin/ggc.sh ]]
then
s_v='/opt/DirX/iddirx/bin/ggc.sh';
local_=$(grep ^'#' "$0" | grep MODIFIED | cut -d'=' -f2 | cut -d'#' -f1 | xargs);
server_=$(grep ^'#' "$s_v" | grep MODIFIED | cut -d'=' -f2 | cut -d'#' -f1 | xargs);
local_verion=$(grep ^'#' "$0" | grep VERSION | cut -d'=' -f2 | cut -d'#' -f1 | xargs);
server_version=$(grep ^'#' "$s_v" | grep VERSION | cut -d'=' -f2 | cut -d'#' -f1 | xargs);

if [[ "$local_" != "$server_" ]] && [[ $(awk -v n1="$local_version" -v n2="$server_version" 'BEGIN { exit (n1 < n2) }' /dev/null) ]]
then
        printf "\n\nIt seems there is a newer version of the script available for download.\nYour version is : $local_verion from $local_\nServer version is : $server_version from $server_ .\n\tDo you whant to update the script now?\n\n\t\t\t[ YES | NO ] / [ Y | N ]\t";
        read answer;
        printf "\n\n";
        if [[ `echo $answer | tr '[:upper:]' '[:lower:]'` == "y" ]] || [[ `echo $answer | tr '[:upper:]' '[:lower:]'` == "yes" ]]
        then
                cp -f -u "$s_v" "$0";
                if [[ "$?" -eq 0 ]]
                then
                        print_to_log "Script updated to version $server_version successfully. Please re-run the command, to use updated version." | tee -a $logfile;
                        exit 0;
                else
                        print_to_log "ERR: RC 9 - Installation interrupted abruptly during installation process." | tee -a "$logfile";
                        exit 9;
                fi;
        else
                printf "\nOK, NOT updating\n\n";
                print_to_log "Newer version of the script was found, but user declined installation" >> $logfile;
        fi;
fi;
fi;
}

insert_adp(){
printf "insert into ggc(name, permission, parameter, ticket, creator, type, description, requester, domain, obligation, when, ldif) values ('${group_name}', '$permission', '$parameter', '$ticket', '$user_ajdi', '$tejp', '$description', '${requester}', '$domina', '$o', '$(date '+%Y/%m/%d')', '$ldif');\ncommit;\n" | adp;
}

group_type_mapping(){
if [[ "$type_" -ge 0 ]] && [[ "$type_" -lt 2 ]]
then
        declare -a group_type;
        group_type=('Standard' 'TeamSafe');
        tejp="${group_type[$type_]}";
else
        print_to_log "ERR: RC 14 - Incorrect Group Type. Run: \"$(basename $0) -h\" to see the list of available Group Types." | tee -a $logfile; exit 14;
fi;
}

get_description(){
if [[ "${#description}" -lt 3 ]] || [[ "${#description}" -gt 300 ]]
then
        description=$ticket
fi;
}

main(){
while getopts "n:d:s:r:o:t:w:b:x:h" INPUT
do
        case "${INPUT}" in
                n) gn="${OPTARG}";;
                d) d="${OPTARG}";;
                s) parameter="${OPTARG}";;
                r) permission="${OPTARG}";;
                o) description="${OPTARG}";;
                t) t="${OPTARG}";;
                w) who_="${OPTARG}";;
                b) o="${OPTARG}";;
                x) type_=${OPTARG};;
                h) clear; get_help "$domains" "$obligations"; exit 0;;
                *) print_to_log "ERR: RC 10 - Incorrectly invoked or incorrect argument. Run: \"$(basename $0) -h\" to see the list of available options." | tee -a $logfile; exit 10; exit 10;;
        esac
done
shift $((OPTIND-1))
}

get_user_id;

declare -A domains;
IFS=$'\n';
for all in $(dxim '(&(objectclass=dxrTargetSystem)(objectclass=dxrContainer)(dxrType=ADS)(dxrState=ENABLED))' cn dxmSpecificAttributes dxrEnvironmentProperties role_ts_group_base dxrOptions | egrep '^cn|^dxmSpecificAttributes|role_ts_group_base|grouprootints' | tr -d '\n' | sed -e 's/cn: /\n/g' -e 's/dxmSpecificAttributes: /|/g' -e 's/dxrEnvironmentProperties: role_ts_group_base /|/g' -e 's/dxrOptions: grouprootints /|/g')
        do
        domains[$(echo $all | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')]="$(echo $all | cut -d'|' -f2- | sed -e 's/Customer //g')";
        done
domains['saacon']="Saacon.net|OU=GrpAdm,OU=SIAM,OU=OPFW,OU=Admin,DC=saacon,DC=net|cn=groups,cn=saacon.net,cn=AD,cn=Single TargetSystems,cn=TargetSystems,cn=ASN-IAM-Central";


declare -A obligations;
for obli in $(dxim '(&(objectClass=dxrObligation)(!(cn=mailbox-enabling)))' cn description | tr -d '\n' | sed -e 's/dn: /\n/g' -e 's/cn: /|/g' -e 's/description: /|/g')
        do
        obligations[$(echo $obli | cut -d'|' -f2 | tr '[:upper:]' '[:lower:]')]="$(echo $obli | cut -d'|' -f3) | $(echo $obli | cut -d'|' -f1)";
        done

if [[ "$#" -ge 10 ]]
then
        main "$@";
        upgrade;
        get_ticket;
        get_domain;
        get_description;
        get_obligation;
        get_requester;
        group_type_mapping;
        get_parameter_dn;
        gen_group_name;
        gen_dien;
        get_permission_dn;
        gen_standard_group;
        if [[ "$?" -eq 0 ]]
        then
                result1=$(printf "\n$ldif\n\n" | dxim_a 2>/dev/null | grep -i 'adding');
                if [[ "$?" -eq 0 ]] && [[ "${#result1}" -gt 1 ]]
                then
                        printf "\nGroup $group_name\tcreated\n";
                        result2=$(update_permission 2>/dev/null | grep -i 'modifying entry');
                        if [[ "$?" -eq 0 ]] && [[ "${#result2}" -gt 1 ]]
                        then
                                printf "Permission $permission modified\n";
                                insert_adp >/dev/null;
                                if [[ "$?" -eq 0 ]]
                                then
                                        printf "Entry added to GGC table in ADP\n\n";
                                fi;
                        fi;
                fi;
        fi;
elif [[ "$#" -eq 0 ]] || [[ "$#" -eq 1 ]] && [[ "$1" == '-h' ]]
then
        get_help "$domains" "$obligations";
        exit 0;
else
        print_to_log "ERR: RC 10 - Incorrectly invoked or incorrect argument. Run: \"$(basename $0) -h\" to see the list of available options." | tee -a $logfile;
        exit 10;
fi

