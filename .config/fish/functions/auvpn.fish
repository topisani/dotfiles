function auvpn
set password (bw get password remote2.au.dk)
echo "$password" | sudo openconnect remote2.au.dk -g AU-ACCESS -u au600085@uni.au.dk -p --passwd-on-stdin
end
