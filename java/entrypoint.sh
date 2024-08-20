#!/bin/bash

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# check if LOG_PREFIX is set
if [ -z "$LOG_PREFIX" ]; then
	LOG_PREFIX="\033[1m\033[33mcontainer@pterodactyl~\033[0m"
fi

# Switch to the container's working directory
cd /home/container || exit 1

# Print Java version
printf "${LOG_PREFIX} java -version\n"
java -version

if [[ "$MALWARE_SCAN" == "1" ]]; then
	echo -e "${LOG_PREFIX} Scanning for malware... (This may take a while)"

	java -jar /MCAntiMalware.jar --scanDirectory . --singleScan true --disableAutoUpdate true

	if [ $? -eq 0 ]; then
		echo -e "${LOG_PREFIX} Malware scan has passed"
	else
		echo -e "${LOG_PREFIX} Malware scan has failed"
		exit 1
	fi
else
	echo -e "${LOG_PREFIX} Skipping malware scan..."
fi

if [[ "$AUTOMATIC_UPDATING" == "1" ]]; then
	if [[ "$SERVER_JARFILE" == "server.jar" ]]; then
		printf "${LOG_PREFIX} Checking for updates...\n"

		# Check if libraries/net/minecraftforge/forge exists
		if [ -d "libraries/net/minecraftforge/forge" ] && [ -z "${HASH}" ]; then
			# get first folder in libraries/net/minecraftforge/forge
			FORGE_VERSION=$(ls libraries/net/minecraftforge/forge | head -n 1)

			# Check if -server.jar or -universal.jar exists in libraries/net/minecraftforge/forge/${FORGE_VERSION}
			FILES=$(ls libraries/net/minecraftforge/forge/${FORGE_VERSION} | grep -E "(-server.jar|-universal.jar)")

			# Check if there are any files
			if [ -n "${FILES}" ]; then
				# get first file in libraries/net/minecraftforge/forge/${FORGE_VERSION}
				FILE=$(echo "${FILES}" | head -n 1)

				# Hash file
				HASH=$(sha256sum libraries/net/minecraftforge/forge/${FORGE_VERSION}/${FILE} | awk '{print $1}')
			fi
		fi

		# Check if libraries/net/neoforged/neoforge folder exists
		if [ -d "libraries/net/neoforged/neoforge" ] && [ -z "${HASH}" ]; then
			# get first folder in libraries/net/neoforged/neoforge
			NEOFORGE_VERSION=$(ls libraries/net/neoforged/neoforge | head -n 1)

			# Check if -server.jar or -universal.jar exists in libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}
			FILES=$(ls libraries/net/neoforged/neoforge/${NEOFORGE_VERSION} | grep -E "(-server.jar|-universal.jar)")

			# Check if there are any files
			if [ -n "${FILES}" ]; then
				# get first file in libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}
				FILE=$(echo "${FILES}" | head -n 1)

				# Hash file
				HASH=$(sha256sum libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/${FILE} | awk '{print $1}')
			fi
		fi

		# Hash server jar file
		if [ -z "${HASH}" ]; then
			HASH=$(sha256sum $SERVER_JARFILE | awk '{print $1}')
		fi

		# Check if hash is set
		if [ -n "${HASH}" ]; then
			API_RESPONSE=$(curl -s "https://versions.mcjars.app/api/v1/build/$HASH")

			# Check if .success is true
			if [ "$(echo $API_RESPONSE | jq -r '.success')" = "true" ]; then
				if [ "$(echo $API_RESPONSE | jq -r '.build.id')" != "$(echo $API_RESPONSE | jq -r '.latest.id')" ]; then
					echo -e "${LOG_PREFIX} New build found. Updating server..."

					BUILD_ID=$(echo $API_RESPONSE | jq -r '.latest.id')
					bash <(curl -s "https://versions.mcjars.app/api/v1/script/$BUILD_ID/bash?echo=false")

					echo -e "${LOG_PREFIX} Server has been updated"
				else
					echo -e "${LOG_PREFIX} Server is up to date"
				fi
			else
				echo -e "${LOG_PREFIX} Could not check for updates. Skipping update check."
			fi
		else
			echo -e "${LOG_PREFIX} Could not find hash. Skipping update check."
		fi
	else
		echo -e "${LOG_PREFIX} Automatic updating is enabled, but the server jar file is not server.jar. Skipping update check."
	fi
fi

# check if libraries/net/minecraftforge/forge exists and the SERVER_JARFILE file does not exist
if [ -d "libraries/net/minecraftforge/forge" ] && [ ! -f "$SERVER_JARFILE" ]; then
	echo -e "${LOG_PREFIX} Downloading Forge server jar file..."
	curl -s https://s3.mcjars.app/forge/ForgeServerJAR.jar -o $SERVER_JARFILE

	echo -e "${LOG_PREFIX} Forge server jar file has been downloaded"
fi

# check if libraries/net/neoforged/neoforge exists and the SERVER_JARFILE file does not exist
if [ -d "libraries/net/neoforged/neoforge" ] && [ ! -f "$SERVER_JARFILE" ]; then
	echo -e "${LOG_PREFIX} Downloading NeoForge server jar file..."
	curl -s https://s3.mcjars.app/neoforge/NeoForgeServerJAR.jar -o $SERVER_JARFILE

	echo -e "${LOG_PREFIX} NeoForge server jar file has been downloaded"
fi

# server.properties
if [ -f "server.properties" ]; then
	# set server-ip to 0.0.0.0
	if grep -q "server-ip=" server.properties; then
		sed -i 's/server-ip=.*/server-ip=0.0.0.0/' server.properties
	else
		echo "server-ip=0.0.0.0" >> server.properties
	fi

	# set server-port to SERVER_PORT
	if grep -q "server-port=" server.properties; then
		sed -i "s/server-port=.*/server-port=${SERVER_PORT}/" server.properties
	else
		echo "server-port=${SERVER_PORT}" >> server.properties
	fi

	# set query.port to SERVER_PORT
	if grep -q "query.port=" server.properties; then
		sed -i "s/query.port=.*/query.port=${SERVER_PORT}/" server.properties
	else
		echo "query.port=${SERVER_PORT}" >> server.properties
	fi
fi

# velocity.toml
if [ -f "velocity.toml" ]; then
	# set bind to 0.0.0.0:SERVER_PORT
	if grep -q "bind" velocity.toml; then
		sed -i "s/bind = .*/bind = \"0.0.0.0:${SERVER_PORT}\"/" velocity.toml
	else
		echo "bind = \"0.0.0.0:${SERVER_PORT}\"" >> velocity.toml
	fi
fi

# config.yml
if [ -f "config.yml" ]; then
	# set query_port to SERVER_PORT
	if grep -q "query_port" config.yml; then
		sed -i "s/query_port: .*/query_port: ${SERVER_PORT}/" config.yml
	else
		echo "query_port: ${SERVER_PORT}" >> config.yml
	fi

	# set host to 0.0.0.0:SERVER_PORT
	if grep -q "host" config.yml; then
		sed -i "s/host: .*/host: 0.0.0.0:${SERVER_PORT}/" config.yml
	else
		echo "host: 0.0.0.0:${SERVER_PORT}" >> config.yml
	fi
fi

if [[ "$OVERRIDE_STARTUP" == "1" ]]; then
	FLAGS=("-Dterminal.jline=false -Dterminal.ansi=true")

	if [[ "$SIMD_OPERATIONS" == "1" ]]; then
		FLAGS+=("--add-modules=jdk.incubator.vector")
	fi

	if [[ "$ADDITIONAL_FLAGS" == "Aikar's Flags" ]]; then
		FLAGS+=("-XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true")
	elif [[ "$ADDITIONAL_FLAGS" == "Velocity Flags" ]]; then
		FLAGS+=("-XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:MaxInlineLevel=15")
	fi

	if [[ "$MINEHUT_SUPPORT" == "Velocity" ]]; then
		FLAGS+=("-Dmojang.sessionserver=https://api.minehut.com/mitm/proxy/session/minecraft/hasJoined")
	elif [[ "$MINEHUT_SUPPORT" == "Waterfall" ]]; then
		FLAGS+=("-Dwaterfall.auth.url=\"https://api.minehut.com/mitm/proxy/session/minecraft/hasJoined?username=%s&serverId=%s%s\")")
	elif [[ "$MINEHUT_SUPPORT" = "Bukkit" ]]; then
		FLAGS+=("-Dminecraft.api.auth.host=https://authserver.mojang.com/ -Dminecraft.api.account.host=https://api.mojang.com/ -Dminecraft.api.services.host=https://api.minecraftservices.com/ -Dminecraft.api.session.host=https://api.minehut.com/mitm/proxy")
	fi

	SERVER_MEMORY_REAL=$(($SERVER_MEMORY*$MAXIMUM_RAM/100))
	PARSED="java ${FLAGS[*]} -Xms256M -Xmx${SERVER_MEMORY_REAL}M -jar ${SERVER_JARFILE}"

	# Display the command we're running in the output, and then execute it with the env
	# from the container itself.
	printf "${LOG_PREFIX} %s\n" "$PARSED"
	# shellcheck disable=SC2086
	exec env ${PARSED}
else
	# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
	# variable format of "${VARIABLE}" before evaluating the string and automatically
	# replacing the values.
	PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

	# Display the command we're running in the output, and then execute it with the env
	# from the container itself.
	printf "${LOG_PREFIX} %s\n" "$PARSED"
	# shellcheck disable=SC2086
	exec env ${PARSED}
fi