Must have ssh for your system which is natively supported in most operating systems
and its easy to set up.

_____________________________________________________________________________________________
Set up NGROK
_____________________________________________________________________________________________

To generate your key:
ssh-keygen -t rsa

Then sign up for ngrok, and follow instructions to make ngrok.yml and place it in the same
directory as your files. Then create a custom domain on ngrok. The line below listed
here starts the server however you will run it at a later step through the bat file.
ngrok http --url=your-custom-url.ngrok-free.app 9000

_____________________________________________________________________________________________
Or set up localhost.run
_____________________________________________________________________________________________

Alternatively you can use localhost.run
Localhost.run server setup:
Upload to:
https://admin.localhost.run/

To start your local server:
run pythonserver.bat with python 3 installed

Type:
ssh -o ServerAliveInterval=60 -R 80:localhost:9000 localhost.run

Or to skip key for above steps type:
ssh -o ServerAliveInterval=60 -R 80:localhost:9000 nokey@localhost.run
Then you can take requests by the link it provides

_____________________________________________________________________________________________
Then set up config file, index and bat file
_____________________________________________________________________________________________

To set up your servers details and API keys, edit the config.js file in static directory.
If needed ctrl + f5 hard refresh gecko and restart server for changes to take effect.
Your password should be the same one you use to log into BitBay web markets as a node.
Also you public key should be registered so users know how to connect to you.

You can set the number of running threads in the config file(the default is 4). However,
when the server is running do not close any of the browser windows and do not take any
of the tabs out of focus. Please leave each firefox window on it's own. The windows can
however be minimized. You may occasionally look at the console or ngrok to report errors.

For security do not put sensitive files in the "static" directory

Next, so people can connect and test with the generic account you can replace the line
var serverPublicKey = ""
in the index.html file with the same public key shown when you log into BitBay with
the same password. Doing this allows users to test the server remotely by visiting the
ngrok page link. Also replace the line in index.html that says
var apiUrl = "https://your-custom-url.ngrok-free.app/api";
with the URL of your ngrok server

Next, in pythonserver.bat replace the line that says:
start cmd /k "ngrok http --url=your-custom-url.ngrok-free.app 9000"
with the actual custom link of your ngrok server

Finally if you are building everything from python directly then replace the line:
server.exe
...with the following line:
python server.py

Otherwise you may use the prebuilt server executable. For security you may choose to download
your own copies of ngrok.exe and of geckodriver.exe as well

_____________________________________________________________________________________________
Run the server
_____________________________________________________________________________________________

Finally load "pythonserver.bat" which will automatically boot up your ngrok server and
your python server. You are of course able to edit the python code and index to run different
apis or use different locally run AI models.

_____________________________________________________________________________________________
Join the community of nodes
_____________________________________________________________________________________________

You may finally share your nodes Polygon or Ethereum address (seen during BitBay web markets
login) as well as your public key and custom ngrok server URL with the BitBay community to be
potentially added to the pool of affiliates. However to be an affiliate you must also be an
active user of the markets. Affiliates do not have to be nodes and may also be marketers.
However when a user doesn't select an affiliate one may be selected randomly among the nodes.

_____________________________________________________________________________________________
Run BitBay web markets simultaneously
_____________________________________________________________________________________________

To allow moderation results to be accessible when your node is offline and to reduce load on
your server, log into BitBay web markets using your password and it should say you are a node.
Then, it will automatically start to build an IPFS database which is shared with users.
There will be gas costs to post this data to the blockchain however it is affordable and you
can choose how many times a day you will scan orders and post the data. Eventually this
data could even be used to improve searches. However, your node must be online for new orders
since they pin to IPFS using your Pinata API or your custom IPFS node.

_____________________________________________________________________________________________
Custom AI models
_____________________________________________________________________________________________

By modifying some of the Python code, a custom AI model could be used for moderation assuming
you are skilled at making a robust set of prompts that have been battle tested for accuracy.
This can be used for image moderation and text moderation(for example using Molmo). Lastly,
you can set up your own IPFS node to reduce the reliance on services like Pinata. This will
allow you to run the entire system at home without having to pay for API keys.