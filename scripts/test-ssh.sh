#!/bin/bash

echo "Testing SSH connectivity..."

for ip in 192.168.56.10 192.168.56.11 192.168.56.12; do
    echo "Testing $ip..."
    
    # Test con vagrant user
    if ssh -i ~/.ssh/ansible_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 vagrant@$ip 'hostname' 2>/dev/null; then
        echo "✅ vagrant@$ip - OK"
    else
        echo "❌ vagrant@$ip - FAILED"
    fi
    
    # Test con ansible user  
    if ssh -i ~/.ssh/ansible_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$ip 'hostname' 2>/dev/null; then
        echo "✅ ansible@$ip - OK"
    else
        echo "❌ ansible@$ip - FAILED"
    fi
    echo ""
done
