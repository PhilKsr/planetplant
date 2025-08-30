import { logger } from '../utils/logger.js';

export const requestLogger = (req, res, next) => {
  const start = Date.now();

  // Capture original end function
  const originalEnd = res.end;
  
  // Override end function to log when response is sent
  res.end = function(...args) {
    // Restore original end function
    res.end = originalEnd;
    
    // Call original end function
    res.end.apply(this, args);
    
    // Calculate response time
    const responseTime = Date.now() - start;
    
    // Log the request
    logger.logRequest(req, res, responseTime);
  };

  next();
};