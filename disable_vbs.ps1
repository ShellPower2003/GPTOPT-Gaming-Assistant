Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Value 0
Write-Output "VBS Disabled. Please restart your system."