import os

# Base path for data
data_base_path = os.environ.get('DATA_BASE_PATH', '/app/data')

# Path for the trained model files
model_file_path = os.path.join(data_base_path, 'models', 'price_model')

# Path for the training price data
training_price_data_path = os.path.join(data_base_path, 'price_data')

# Supported tokens and timeframes
supported_tokens = ["BTC", "ETH", "SOL", "BNB", "ARB","MEME"]
supported_timeframes = ["5m","10m", "20m", "1d","1h"]
