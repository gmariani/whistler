:: Migrate from Signed to renewed certificate
set adt_bin="C:\Program Files (x86)\Adobe\Adobe Flash Builder 4.6\sdks\4.6.0\bin\adt.bat"
set old_cert="D:\Web Development\Personal\108298224.p12"
set old_pass=370412
set old_cert2="D:\Web Development\Personal\CourseVectorCert.p12"
set old_pass2=namrepus
%adt_bin% -migrate -storetype pkcs12 -keystore %old_cert2% -storepass %old_pass2% Whistler.air Whistler-1-1-0.air
pause