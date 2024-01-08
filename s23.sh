#!/bin/bash

echo "This script will install and set up S23 miners."
read -p "Press Enter to continue or Ctrl+C to cancel."

# Update and upgrade system
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Install Node.js and npm
echo "Installing Node.js and npm..."
sudo apt install nodejs npm -y

# Install pm2 globally
echo "Installing pm2 globally..."
sudo npm i -g pm2

# Clone the repository
echo "Cloning the S23 miners repository..."
git clone https://github.com/NicheTensor/NicheImage.git
cd NicheImage

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt
pip install -e .

# Cold wallet setup
read -p "Enter 1 to create a new cold wallet or 2 to import an existing one: " cold_wallet_choice

if [ "$cold_wallet_choice" = "1" ]; then
    NEW_COLDKEY_OUTPUT=$(btcli w new_coldkey --no_password)
    echo "$NEW_COLDKEY_OUTPUT" > Backup
else
    echo "Enter the 12 seed words for the cold wallet:"
    read -p "Word 1: " W1
    read -p "Word 2: " W2
    read -p "Word 3: " W3
    read -p "Word 4: " W4
    read -p "Word 5: " W5
    read -p "Word 6: " W6
    read -p "Word 7: " W7
    read -p "Word 8: " W8
    read -p "Word 9: " W9
    read -p "Word 10: " W10
    read -p "Word 11: " W11
    read -p "Word 12: " W12

    MNEMONIC="$W1 $W2 $W3 $W4 $W5 $W6 $W7 $W8 $W9 $W10 $W11 $W12"
    NEW_COLDKEY_OUTPUT=$(btcli w regen_coldkey --mnemonic "$MNEMONIC" --no_password)
    echo "$NEW_COLDKEY_OUTPUT" > Backup
fi

# Hot wallet setup
read -p "Enter 1 to create a new hot wallet or 2 to import an existing one: " hot_wallet_choice

if [ "$hot_wallet_choice" = "1" ]; then
    NEW_HOTKEY_OUTPUT=$(btcli w new_hotkey)
    echo "$NEW_HOTKEY_OUTPUT" >> Backup
else
    echo "Enter the 12 seed words for the hot wallet:"
    read -p "Word 1: " W13
    read -p "Word 2: " W14
    read -p "Word 3: " W15
    read -p "Word 4: " W16
    read -p "Word 5: " W17
    read -p "Word 6: " W18
    read -p "Word 7: " W19
    read -p "Word 8: " W20
    read -p "Word 9: " W21
    read -p "Word 10: " W22
    read -p "Word 11: " W23
    read -p "Word 12: " W24

    MNEMONIC="$W13 $W14 $W15 $W16 $W17 $W18 $W19 $W20 $W21 $W22 $W23 $W24"
    NEW_HOTKEY_OUTPUT=$(btcli w regen_hotkey --mnemonic "$MNEMONIC")
    echo "$NEW_HOTKEY_OUTPUT" >> Backup
fi

# Check if hotkey is registered
HOTKEY_REGISTERED=$(btcli w is_registered --wallet_name default --wallet.hotkey default)

if [ "$HOTKEY_REGISTERED" = "true" ]; then
    echo "Hot wallet is already registered. Continuing with the script..."
else
    echo "Hot wallet is not registered. Fund the cold key and check if the wallet is funded with the following command:"
    btcli w list

    read -p "Is the wallet funded? Do you want to attempt registration on S23? (y/n): " FUNDING_CONFIRMATION

    if [ "$FUNDING_CONFIRMATION" = "y" ]; then
        btcli s register --netuid 23 --wallet_name default --wallet.hotkey default --no_prompt

        # Check if registration was successful
        REGISTRATION_SUCCESSFUL=$(btcli s is_registered --wallet_name default --wallet.hotkey default)

        if [ "$REGISTRATION_SUCCESSFUL" = "true" ]; then
            echo "Registration successful. Continuing with the script..."
        else
            echo "Registration failed. Please check the wallet funding and try again."
            exit 1
        fi
    else
        echo "Registration skipped. Please fund the cold key and manually register the hot wallet using 'btcli s register'."
        exit 1
    fi
fi

# Network configuration
read -p "Enter your public IP: " PUBIP
read -p "Enter the API port: " API
read -p "Enter the Miner 1 port: " MINER1

# Model choice
read -p "Choose a model: 1 for RealisticVision, 2 for SDXLTurbo: " MODEL_CHOICE

if [ "$MODEL_CHOICE" = "1" ]; then
    pm2 start python3 --name "RealisticVision" -- -m dependency_modules.miner_endpoint.app --port "$API" --model_name RealisticVision
else
    pm2 start python3 --name "SDXLTurbo" -- -m dependency_modules.miner_endpoint.app --port "$API" --model_name SDXLTurbo
fi

# Countdown
echo "Starting miner in 30 seconds..."
for i in {30..1}; do
    echo -ne "Time left: $i seconds\033[0K\r"
    sleep 1
done

# Start miner
cd ~/NicheImage/neurons/miner/
pm2 start miner.py --interpreter python3 --name S23-1 -- --netuid 23 --wallet.name default --wallet.hotkey default --subtensor.network finney --generate_endpoint "http://$PUBIP:$API/generate" --info_endpoint "http://$PUBIP:$API/info" --axon.port "$MINER1"

echo "Miner started successfully!"

# Wait for 3 seconds
sleep 3

# Display logs
pm2 logs 1
