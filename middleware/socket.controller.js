let io; 

function initializeSocket(server) {
    io = require('socket.io')(server, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST']
      }
    });
    
    io.on('connection', (socket) => {
      console.log('Socket intialized');
    });
  }
module.exports = {
  initializeSocket
};