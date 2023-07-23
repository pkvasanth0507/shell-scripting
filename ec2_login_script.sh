#!/bin/bash

set -e
set -o pipefail


AWS_ACCESS_KEY="ENTER ACCESS KEY"
AWS_SECRET_ACCESS_KEY="ENTER SECRET ACCESS KEY"
AWS_REGION="us-east-1"  # Replace with your desired AWS region


# Configure AWS CLI with provided access key and secret access key
aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_REGION"

read -p "Enter the path to your AWS key pair file (.pem): " KEY_PAIR_FILE

# Validate the file path
if [ ! -f "$KEY_PAIR_FILE" ]; then
    echo "Error: The specified file does not exist or is not accessible."
    exit 1
fi


# Function to start an EC2 instance by its instance ID
start_instance() {
    local instance_id="$1"
    aws ec2 start-instances --instance-ids "$instance_id"
}

# List names and other details of all EC2 instances with the "Name" tag
instance_info=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value | [0], InstanceId, State.Name, PublicDnsName]' --output json)

# Parse the instance information into arrays
names=($(echo "$instance_info" | jq -r '.[][][0]'))
instance_ids=($(echo "$instance_info" | jq -r '.[][][1]'))
states=($(echo "$instance_info" | jq -r '.[][][2]'))
public_dns_names=($(echo "$instance_info" | jq -r '.[][][3]'))

# Display a menu with instance names
echo "Select an instance to start:"
for ((i=0; i<${#names[@]}; i++)); do
    echo "$((i+1)). Name: ${names[i]} (Instance ID: ${instance_ids[i]}, State: ${states[i]}, Public DNS: ${public_dns_names[i]})"
done

# Get user input for the selected instance
read -p "Enter the number corresponding to the instance you want to start: " selected_index

# Validate user input
if [[ "$selected_index" =~ ^[0-9]+$ && "$selected_index" -ge 1 && "$selected_index" -le "${#names[@]}" ]]; then
    selected_instance_index=$((selected_index-1))
    selected_instance_id="${instance_ids[selected_instance_index]}"
    selected_instance_state="${states[selected_instance_index]}"

    if [[ "$selected_instance_state" == "running" ]]; then
        echo "The selected instance is already running."
    else
        start_instance "$selected_instance_id"
        echo "Starting the selected instance with Instance ID: $selected_instance_id"
	echo "Waiting for the instance to be fully up and running..."
        sleep 30  # Wait for 30 seconds (you can adjust this as needed)
    fi



# Get the public IP address of the selected instance
    public_ip=$(aws ec2 describe-instances --instance-ids "$selected_instance_id" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text )

    # Connect to the instance via SSH
    if [[ -n "$public_ip" ]]; then
        echo "Connecting to the instance with Public IP: $public_ip..."
        ssh -i "$KEY_PAIR_FILE" ubuntu@"$public_ip"             # CHANGE ubuntu to ec2_user if needed
    else
        echo "Failed to retrieve the public IP address of the instance."
    fi
else
    echo "Invalid input. Please enter a valid number corresponding to the instance you want to start and connect."
fi

