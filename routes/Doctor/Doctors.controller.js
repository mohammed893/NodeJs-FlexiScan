const {pool} = require('../../models/configrations');

const getDoctor = async(req , res) => {
    // doctor_id = req.user.user_id;
    // console.log(doctor_id);
    // try{
    //     const result = await pool.query('SELECT * FROM doctors WHERE doctor_id = $1', [doctor_id]);
    //     if(result.rows.length === 0){
    //         return res.status(404).json("Doctor Not found !");
    //     }
    //     res.status(200).json(result.rows[0]);
    // }catch(err){
    //     console.log("error getting a doctor : " , err)
    //     res.status(500).json({error : "Server Error while finding a doctor !"});
    // }
    return res.status(200).json("Doctor Not found !!!");}

module.exports = {
    getDoctor
}
