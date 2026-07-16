Pre-Requisite steps:

1. Extract the IRISSystemManagement folder 
2. Ensure that parameters.ps1, Setup.ps1, cleanup.ps1 are unblocked by accessing each file's properties > General tab
3. Ensure docker desktop is running
4. Ensure that ports 8080, 8081, 8082, 8443, 51773, 52773, 61773, 62773, 21881, 21882, 21883 are available, stop any containers that may be using those ports
5. Open Windows Terminal/Powershell and cd to the IRISSystemManagement folder
6. Run > docker login -u="veeraya.s@parallel-dcs.com" -p="QaxhhYrIQi9qblpq43go57mmnoTVosEOgD4XFKcek5Qb"  containers.intersystems.com
7. Run > ./Setup.ps1 to pull the images and start the containers
8. Access the nodes as follows:
	irisa node - http://127.0.0.1:8081/csp/sys/Utilhome.csp
	irisb node - http://127.0.0.1:8082/csp/sys/Utilhome.csp
     load balancer - http://127.0.0.1:8080/csp/sys/Utilhome.csp