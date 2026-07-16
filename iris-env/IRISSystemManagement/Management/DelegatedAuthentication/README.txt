Delegated Authentication Example.   

Parts:
1. ZAuth.xml - Contains ZAUTHENTICATE.mac. Install this into the %SYS namespace. The routine
authenticates users against the MYUSERS global.
2. Zen.xml - Contains Application.cls and CreateDelegatedUser.cls. This is a Zen form for
adding users (user name, password, full name) to the MYUSERS global.

Installation:
1. Import ZAUTHENTICATE.mac into the %SYS namespace. Note that this will overwrite any already existing ZAUTHENTICATE routine, so you may want to take precautions.
2. Import the Zen classes into whatever namespace you choose.
3. If the Zen classes are not in %SYS, you must map the MYUSERS global to %SYS. Here are the steps:
	i. From the SMP home page click "Configuration->Namespaces->Global Mappings"
	ii. Click "Global Mappings" in the %SYS row of the table.
	iii. Enter the following information:
		Globall Database Location: <Database containing MYUSERS>
		Global Name: MYUSERS
	iv. Click "OK"
	v. Click "Save Changes"
	
Demonstration:
1. Open SecurityTutorial.CreateDelegatedUsers.cls in a Web Browser (open the class def in Caché Studio and click View->Web Page) and create a user.
2. Enable Delegated Authentication system wide.
3. Set whatever service you are demonstrating to use Delegated authentication as its authentication mechanism. If demonstrating with DSN, set for %Service_Bindings. (Remember, Studio uses %Service_Bindings.)
4. Login using the connection tool (such as through DSN) and service set to delegated authentication. Use the newly created user name and password.
5. View the user information in the SMP. "Security Management->Users"

