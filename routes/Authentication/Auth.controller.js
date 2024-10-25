const {pool} = require('../../models/configrations');
const jwt = require('jsonwebtoken');
require("dotenv").config()
const bcrypt = require("bcrypt");
const Login = async (req, res) => {
    const email = req.body.email;
    const password = req.body.password;
    const isDoctor = req.body.type === "d"; 
    const table = isDoctor ? 'doctors' : 'patients'; 

    try {
       
        const result = await pool.query(`SELECT * FROM ${table} WHERE email = $1`, [email]);
        
        if (result.rows.length === 0) {
            return res.status(401).json({ error: "Invalid email or password." });
        }

        const user = result.rows[0];

        
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            console.log("!isPasswordValid")
            return res.status(401).json({ error: "Invalid email or password." });
        }

       
        const accessToken = jwt.sign(
            { user_id: user.doctor_id || user.patient_id },
            process.env.ACCESS_TOKEN_SECRET,
            { expiresIn: '1m' }
        );

       
        return res.json({ accessToken });
    } catch (err) {
        console.error("Error during login:", err);
        if (!res.headersSent) {
            return res.status(500).json({ error: "Server error during login!" });
        }
    }
};
const AuthToken = async(req , res , next) => {
    const authHeader = req.headers["authorization"]
    const token = authHeader && authHeader.split(' ')[1];
    if(token == null) return res.sendStatus(401);
    jwt.verify(token , process.env.ACCESS_TOKEN_SECRET , (err , user)=>
    {
        if(err) { console.log(err)
            return res.status(403)}
        req.user = user
        console.log("Authenticated");
        next();
    })
} 

module.exports = {Login , AuthToken}