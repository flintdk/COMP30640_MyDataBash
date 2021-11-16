#!/bin/bash
str="a\bc";
read x <<< "$str";
read -r y <<< "$str";
echo "x is $x";
echo "y is $y"