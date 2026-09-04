@echo off
echo ================================================================================
echo CROP DISEASE DETECTION API SERVER
echo ================================================================================
echo.
echo Starting Flask API server with trained model...
echo Model: 72.19%% accuracy, 23 disease types
echo.
echo Server will run on: http://localhost:5000
echo React app should connect to: http://localhost:5000/api/predict
echo.
echo Press Ctrl+C to stop the server
echo ================================================================================
echo.

python api_server.py

pause