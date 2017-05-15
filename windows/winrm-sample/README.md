Add winrm connection info to env vars:

```
export WINRM_ENDPOINT="http://52.58.146.151:5985/wsman"
export WINRM_PASSWORD="password"
export WINRM_USER="Administrator"

```

Run the ruby script with windows env vars passed as parameters. The ps1 script uses VHD_URL env var to download the gzipped vhd.

```
ruby deploy_cnap_vhd.rb VHD_URL=https://s3-us-west-1.amazonaws.com/clients.als.hpcloud.com/ro-artifacts/hcf-mssql2012-vhds/2-2016-04-27_09-00-13/mssql2012.gz MSSQL_SA_PASSWORD=password VAR3=value VAR4=value
```

Alternatively, install the [golang winrm package](https://github.com/masterzen/winrm) and run the following command:
```
(echo '$env:MSSQL_SA_PASSWORD="pass1234_Ab"' && cat deploy_cnap_vhd.ps1 && echo "exit") | winrm -hostname 192.168.77.78 "powershell -NonInteractive -Command -"
```