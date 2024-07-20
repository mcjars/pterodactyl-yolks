#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Print Java version
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"
java -version

if [[ "$AUTOMATIC_UPDATING" == "1" ]]; then
	printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mChecking for updates...\n"

	# Check if libraries/net/minecraftforge/forge exists
	if [ -d "libraries/net/minecraftforge/forge" ] && [ -z "${HASH}" ]; then
		# get first folder in libraries/net/minecraftforge/forge
		FORGE_VERSION=$(ls libraries/net/minecraftforge/forge | head -n 1)

		# Check if unix_args.txt exists in libraries/net/minecraftforge/forge/${FORGE_VERSION}
		if [ -f "libraries/net/minecraftforge/forge/${FORGE_VERSION}/unix_args.txt" ]; then
			HASH=$(sha256sum libraries/net/minecraftforge/forge/${FORGE_VERSION}/unix_args.txt | awk '{print $1}')
		fi
	fi

	# Check if libraries/net/neoforged/neoforge folder exists
	if [ -d "libraries/net/neoforged/neoforge" ] && [ -z "${HASH}" ]; then
		# get first folder in libraries/net/neoforged/neoforge
		NEOFORGE_VERSION=$(ls libraries/net/neoforged/neoforge | head -n 1)

		# Check if unix_args.txt exists in libraries/net/neoforged/neoforge/${FORGE_VERSION}
		if [ -f "libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt" ]; then
			HASH=$(sha256sum libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt | awk '{print $1}')
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
				echo -e "\033[1m\033[33mcontainer@pterodactyl~ \033[0mNew build found. Updating server..."

				BUILD_ID=$(echo $API_RESPONSE | jq -r '.latest.id')
				bash <(curl -s "https://versions.mcjars.app/api/v1/script/$BUILD_ID/bash?echo=false")

				echo -e "\033[1m\033[33mcontainer@pterodactyl~ \033[0mServer has been updated"
			else
				echo -e "\033[1m\033[33mcontainer@pterodactyl~ \033[0mServer is up to date"
			fi
		else
			echo -e "\033[1m\033[33mcontainer@pterodactyl~ \033[0mCould not check for updates. Skipping update check."
		fi
	else
		echo -e "\033[1m\033[33mcontainer@pterodactyl~ \033[0mCould not find hash. Skipping update check."
	fi
fi

if [[ "$OVERRIDE_STARTUP" == "1" ]]; then
	FLAGS=("-Dterminal.jline=false -Dterminal.ansi=true")

	if [[ "$SIMD_OPERATIONS" == "1" ]]; then
		FLAGS+=("--add-modules=jdk.incubator.vector")
	fi

	if [[ "$ADDITIONAL_FLAGS" == "Aikar's Flags" ]]; then
		FLAGS+=("-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true")
	elif [[ "$ADDITIONAL_FLAGS" == "Velocity Flags" ]]; then
		FLAGS+=("-XX:+AlwaysPreTouch -XX:+ParallelRefProcEnabled -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:MaxInlineLevel=15")
	fi

	if [[ "$MINEHUT_SUPPORT" == "Velocity" ]]; then
		FLAGS+=("-Dmojang.sessionserver=https://api.minehut.com/mitm/proxy/session/minecraft/hasJoined")
	elif [[ "$MINEHUT_SUPPORT" == "Waterfall" ]]; then
		FLAGS+=("-Dwaterfall.auth.url=\"https://api.minehut.com/mitm/proxy/session/minecraft/hasJoined?username=%s&serverId=%s%s\")")
	elif [[ "$MINEHUT_SUPPORT" = "Bukkit" ]]; then
		FLAGS+=("-Dminecraft.api.auth.host=https://authserver.mojang.com/ -Dminecraft.api.account.host=https://api.mojang.com/ -Dminecraft.api.services.host=https://api.minecraftservices.com/ -Dminecraft.api.session.host=https://api.minehut.com/mitm/proxy")
	fi

	SERVER_MEMORY_REAL=$(($SERVER_MEMORY*$MAXIMUM_RAM/100))
	PARSED="java ${FLAGS[*]} -Xms${SERVER_MEMORY_REAL}M -Xmx${SERVER_MEMORY_REAL}M -jar ${SERVER_JARFILE}"

	# Display the command we're running in the output, and then execute it with the env
	# from the container itself.
	printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
	# shellcheck disable=SC2086
	exec env ${PARSED}
else
	# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
	# variable format of "${VARIABLE}" before evaluating the string and automatically
	# replacing the values.
	PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

	# Display the command we're running in the output, and then execute it with the env
	# from the container itself.
	printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
	# shellcheck disable=SC2086
	exec env ${PARSED}
fi