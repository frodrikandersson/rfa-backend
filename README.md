# Whiteout survival Alliance homepage
If you've stumbled upon this random side-project, why are you still here?
If you still decide to look at it then I wish you the best of luck!
A friend of mine and myself decided to make this website while we're still learning various development languages so I can't guarantee the most readable layout.


# Are you an invited developer?
You'll find a tutorial below on how to properly set-up your project so you're connected to everything required for this project, assuming you're using VSC.

> 1. Press the search field at the top and write ">Git: Clone", Press enter for "Clone from Github".
> 2. You'll need both of the following projects. (repeat > 1. until you've cloned both projects)
  2.a https://github.com/frodrikandersson/rfa-frontend
  2.b https://github.com/frodrikandersson/rfa-backend

Congratulations, you've successfully cloned both projects. Now open up the projects in any way you like. I prefer to see both projects in one workspace.

# How to setup the backend
In order to partake in the database the docker is pointed towards you'll need a login URL provided by the original creator of this project, that would be exoquil. Send a message to me and I'll answer it eventually, hopefully, unless I'm dead.

  Follow the next steps if you wish to connect to docker
> 1. Message exoquil on github to get your own connection url
> 2. Create a file in the root folder (same folder as the docker-compose.yml file) and name it .env
> 3. Inside .env, type this: DATABASE_URL=UrlFromExoquil
UrlFromExoquil needs to be replaced with the Url provided by me.
> 4. Make sure you have the docker application installed and started on your PC
> 5. Right click the folder rfa-backend and click "open in integrated terminal"
> 6. Enter "docker compose up"

  Follow the next steps to finalize the backend setup
> 1. Right click the folder rfa-backend and click "open in integrated terminal" (if you've already done this earlier, skip this step)
> 2. Enter "npm install"
> 3. Right click the folder rfa-frontend-vite and click "open in integrated terminal"
> 4. Enter "npm install"


# Good job! Whenever you come back to the project you'll need to do this in order to start the project again.

> Enter "npm run dev" to start the backend or frontend locally.
> If you have docker set up you can start the docker connection through docker desktop. Click on "Containers", find "rfa-backend" and press the start button.

When we push this live we'll change some localhost urls to Vercels provided url, or something else.