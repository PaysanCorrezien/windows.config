
 #Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "PrintScreenKeyForSnippingEnabled" -Value 0

# set machine / user policy
# set-exeutionpolicy  unrestricted
# set-executionpolicy -scope currentuser -executionpolicy unrestricted
# get-executionpolicy -list
#
#        scope executionpolicy
#        ----- ---------------
#machinepolicy       undefined
#   userpolicy       undefined
#      process       undefined
#  currentuser    unrestricted
# localmachine    unrestricted
#
# rustup component add rust-analyzer for nvim

# git config --global core.autocrlf true
# scoop install extras/musicbee
