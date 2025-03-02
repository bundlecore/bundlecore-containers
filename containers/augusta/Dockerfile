# Use the official Python3.8 slim image as a base image
FROM python:3.8-slim
## Augusta documentation says it requires Python 3.7 or 3.8 https://github.com/JanaMus/Augusta?tab=readme-ov-file#quick-guide 

# Set the working directory
WORKDIR /app

# Install Augusta
RUN pip install Augusta

# Command to run the application
CMD ["python", "-m", "Augusta"]