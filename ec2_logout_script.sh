#!/bin/bash

set -e
set -o pipefail


# Replace these with your actual AWS access key and secret access key
AWS_ACCESS_KEY="ENTER ACCESS KEY"
AWS_SECRET_ACCESS_KEY="ENTER SECRET ACCESS KEY"
AWS_REGION="us-east-1"  # Replace with your desired AWS region

# Configure AWS CLI with provided access key and secret access key
aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_REGION"

# Function to stop an EC2 instance by its instance ID
stop_instance() {
    local instance_id="$1"
    aws ec2 stop-instances --instance-ids "$instance_id"
}

# List names and other details of all EC2 instances with the "Name" tag
instance_info=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value | [0], InstanceId, State.Name, PublicDnsName]' --output json)

# Parse the instance information into arrays
names=($(echo "$instance_info" | jq -r '.[][][0]'))
instance_ids=($(echo "$instance_info" | jq -r '.[][][1]'))
states=($(echo "$instance_info" | jq -r '.[][][2]'))
public_dns_names=($(echo "$instance_info" | jq -r '.[][][3]'))

# Display a menu with instance names
echo "Select an instance to stop:"
for ((i=0; i<${#names[@]}; i++)); do
    echo "$((i+1)). ${names[i]} (Instance ID: ${instance_ids[i]}, State: ${states[i]}, Public DNS: ${public_dns_names[i]})"
done

# Get user input for the selected instance
read -p "Enter the number corresponding to the instance you want to stop: " selected_index

# Validate user input
if [[ "$selected_index" =~ ^[0-9]+$ && "$selected_index" -ge 1 && "$selected_index" -le "${#names[@]}" ]]; then
    selected_instance_index=$((selected_index-1))
    selected_instance_id="${instance_ids[selected_instance_index]}"
    selected_instance_state="${states[selected_instance_index]}"

    if [[ "$selected_instance_state" == "stopped" ]]; then
        echo "The selected instance is already stopped."
    else
        aws ec2 stop-instances --instance-ids "$selected_instance_id"
        echo "Stopping the selected instance with Instance ID: $selected_instance_id"
    fi
else
    echo "Invalid input. Please enter a valid number corresponding to the instance you want to stop."
fi

