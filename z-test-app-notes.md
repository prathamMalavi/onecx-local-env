app1-8.10.0-onecx-angular-21-module-test


app2-8.6.0-onecx-angular-21-module-test


app3-8.9.0-onecx-angular-21-module-test





onecx-angular-21-module-test

app-name
app1-onecx-angular-21-module-test
app2-onecx-angular-21-module-test
app3-onecx-angular-21-module-test
app4-onecx-angular-21-module-test

app-id
app1-angular-21-ui
app2-angular-21-ui\
app3-angular-21-ui\
app4-angular-21-ui\


base-path
/app1-angular-21-test/
/app2-angular-21-test/
/app3-angular-21-test/
/app4-angular-21-test/


./RemoteModule


ocx-test-component-21
app1-8.10.0-onecx-angular-21-module-test
app2-8.6.0-onecx-angular-21-module-test
app3-8.9.0-onecx-angular-21-module-test



app1
npm run start -- --port=4019

app2
npm run start -- --port=4022

app3
npm run start -- --port=4025

app4
npm run start -- --port=4028



rm -rf node_modules/ && rm -rf .angular/ dist/ && npm i && npm run build

kill -9 $(lsof -t -i:4019)
kill -9 $(lsof -t -i:4022)
kill -9 $(lsof -t -i:4025)
kill -9 $(lsof -t -i:4028)




