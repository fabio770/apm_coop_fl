/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

static void
get_stabilize_roll(int32_t target_angle)
{
    // angle error
    target_angle            = wrap_180(target_angle - ahrs.roll_sensor);

    // limit the error we're feeding to the PID
    target_angle            = constrain(target_angle, -4500, 4500);

        // convert to desired Rate:
    int32_t target_rate = g.pi_stabilize_roll.get_p(target_angle);

    int16_t i_stab;
    if(labs(ahrs.roll_sensor) < 500) {
        target_angle            = constrain(target_angle, -500, 500);
        i_stab                          = g.pi_stabilize_roll.get_i(target_angle, G_Dt);
    }else{
        i_stab                          = g.pi_stabilize_roll.get_integrator();
    }

    // set targets for rate controller
    set_roll_rate_target(target_rate+i_stab, EARTH_FRAME);
}

static void
get_stabilize_pitch(int32_t target_angle)
{
    // angle error
    target_angle            = wrap_180(target_angle - ahrs.pitch_sensor);

    // limit the error we're feeding to the PID
    target_angle            = constrain(target_angle, -4500, 4500);

    // convert to desired Rate:
    int32_t target_rate = g.pi_stabilize_pitch.get_p(target_angle);

    int16_t i_stab;
    if(labs(ahrs.pitch_sensor) < 500) {
        target_angle            = constrain(target_angle, -500, 500);
        i_stab                          = g.pi_stabilize_pitch.get_i(target_angle, G_Dt);
    }else{
        i_stab                          = g.pi_stabilize_pitch.get_integrator();
    }

    // set targets for rate controller
    set_pitch_rate_target(target_rate + i_stab, EARTH_FRAME);
}

static void
get_stabilize_yaw(int32_t target_angle)
{
    int32_t target_rate,i_term;
    int32_t angle_error;
    int32_t output = 0;

    // angle error
    angle_error             = wrap_180(target_angle - ahrs.yaw_sensor);

    // limit the error we're feeding to the PID

    angle_error             = constrain(angle_error, -4500, 4500);

    // convert angle error to desired Rate:
    target_rate = g.pi_stabilize_yaw.get_p(angle_error);
    i_term = g.pi_stabilize_yaw.get_i(angle_error, G_Dt);

    // do not use rate controllers for helicotpers with external gyros
#if FRAME_CONFIG == HELI_FRAME
    if(motors.ext_gyro_enabled) {
        g.rc_4.servo_out = constrain((target_rate + i_term), -4500, 4500);
    }
#endif

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;              // used to slow down logging of PID values to dataflash
    // log output if PID logging is on and we are tuning the yaw
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_YAW_KP || g.radio_tuning == CH6_YAW_RATE_KP) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_YAW_KP, angle_error, target_rate, i_term, 0, output, tuning_value);
        }
    }
#endif

    // set targets for rate controller
    set_yaw_rate_target(target_rate+i_term, EARTH_FRAME);
}

static void
get_acro_roll(int32_t target_rate)
{
    target_rate = target_rate * g.acro_p;

    // set targets for rate controller
    set_roll_rate_target(target_rate, BODY_FRAME);
}

static void
get_acro_pitch(int32_t target_rate)
{
    target_rate = target_rate * g.acro_p;

    // set targets for rate controller
    set_pitch_rate_target(target_rate, BODY_FRAME);
}

static void
get_acro_yaw(int32_t target_rate)
{
    target_rate = target_rate * g.acro_p;

    // set targets for rate controller
    set_yaw_rate_target(target_rate, BODY_FRAME);
}

// Roll with rate input and stabilized in the earth frame
static void
get_roll_rate_stabilized_ef(int32_t stick_angle)
{
    int32_t angle_error = 0;

    // convert the input to the desired roll rate
    int32_t target_rate = stick_angle * g.acro_p - (roll_axis * g.acro_balance_roll)/100;

    // convert the input to the desired roll rate
    roll_axis += target_rate * G_Dt;
    roll_axis = wrap_180(roll_axis);

    // ensure that we don't reach gimbal lock
    if (roll_axis > 4500 || roll_axis < -4500) {
        roll_axis	= constrain(roll_axis, -4500, 4500);
        angle_error = wrap_180(roll_axis - ahrs.roll_sensor);
    } else {
        // angle error with maximum of +- max_angle_overshoot
        angle_error = wrap_180(roll_axis - ahrs.roll_sensor);
        angle_error	= constrain(angle_error, -MAX_ROLL_OVERSHOOT, MAX_ROLL_OVERSHOOT);
    }

    if (motors.armed() == false || ((g.rc_3.control_in == 0) && !ap.failsafe)) {
        angle_error = 0;
    }

    // update roll_axis to be within max_angle_overshoot of our current heading
    roll_axis = wrap_180(angle_error + ahrs.roll_sensor);

    // set earth frame targets for rate controller

    // set earth frame targets for rate controller
	set_roll_rate_target(g.pi_stabilize_roll.get_p(angle_error) + target_rate, EARTH_FRAME);
}

// Pitch with rate input and stabilized in the earth frame
static void
get_pitch_rate_stabilized_ef(int32_t stick_angle)
{
    int32_t angle_error = 0;

    // convert the input to the desired pitch rate
    int32_t target_rate = stick_angle * g.acro_p - (pitch_axis * g.acro_balance_pitch)/100;

    // convert the input to the desired pitch rate
    pitch_axis += target_rate * G_Dt;
    pitch_axis = wrap_180(pitch_axis);

    // ensure that we don't reach gimbal lock
    if (pitch_axis > 4500 || pitch_axis < -4500) {
        pitch_axis	= constrain(pitch_axis, -4500, 4500);
        angle_error = wrap_180(pitch_axis - ahrs.pitch_sensor);
    } else {
        // angle error with maximum of +- max_angle_overshoot
        angle_error = wrap_180(pitch_axis - ahrs.pitch_sensor);
        angle_error	= constrain(angle_error, -MAX_PITCH_OVERSHOOT, MAX_PITCH_OVERSHOOT);
    }

    if (motors.armed() == false || ((g.rc_3.control_in == 0) && !ap.failsafe)) {
        angle_error = 0;
    }

    // update pitch_axis to be within max_angle_overshoot of our current heading
    pitch_axis = wrap_180(angle_error + ahrs.pitch_sensor);

    // set earth frame targets for rate controller
	set_pitch_rate_target(g.pi_stabilize_pitch.get_p(angle_error) + target_rate, EARTH_FRAME);
}

// Yaw with rate input and stabilized in the earth frame
static void
get_yaw_rate_stabilized_ef(int32_t stick_angle)
{

    int32_t angle_error = 0;

    // convert the input to the desired yaw rate
    int32_t target_rate = stick_angle * g.acro_p;

    // convert the input to the desired yaw rate
    nav_yaw += target_rate * G_Dt;
    nav_yaw = wrap_360(nav_yaw);

    // calculate difference between desired heading and current heading
    angle_error = wrap_180(nav_yaw - ahrs.yaw_sensor);

    // limit the maximum overshoot
    angle_error	= constrain(angle_error, -MAX_YAW_OVERSHOOT, MAX_YAW_OVERSHOOT);

    if (motors.armed() == false || ((g.rc_3.control_in == 0) && !ap.failsafe)) {
    	angle_error = 0;
    }

    // update nav_yaw to be within max_angle_overshoot of our current heading
    nav_yaw = wrap_360(angle_error + ahrs.yaw_sensor);

    // set earth frame targets for rate controller
	set_yaw_rate_target(g.pi_stabilize_yaw.get_p(angle_error)+target_rate, EARTH_FRAME);
}

// set_roll_rate_target - to be called by upper controllers to set roll rate targets in the earth frame
void set_roll_rate_target( int32_t desired_rate, uint8_t earth_or_body_frame ) {
    rate_targets_frame = earth_or_body_frame;
    if( earth_or_body_frame == BODY_FRAME ) {
        roll_rate_target_bf = desired_rate;
    }else{
        roll_rate_target_ef = desired_rate;
    }
}

// set_pitch_rate_target - to be called by upper controllers to set pitch rate targets in the earth frame
void set_pitch_rate_target( int32_t desired_rate, uint8_t earth_or_body_frame ) {
    rate_targets_frame = earth_or_body_frame;
    if( earth_or_body_frame == BODY_FRAME ) {
        pitch_rate_target_bf = desired_rate;
    }else{
        pitch_rate_target_ef = desired_rate;
    }
}

// set_yaw_rate_target - to be called by upper controllers to set yaw rate targets in the earth frame
void set_yaw_rate_target( int32_t desired_rate, uint8_t earth_or_body_frame ) {
    rate_targets_frame = earth_or_body_frame;
    if( earth_or_body_frame == BODY_FRAME ) {
        yaw_rate_target_bf = desired_rate;
    }else{
        yaw_rate_target_ef = desired_rate;
    }
}

// update_rate_contoller_targets - converts earth frame rates to body frame rates for rate controllers
void
update_rate_contoller_targets()
{
    if( rate_targets_frame == EARTH_FRAME ) {
        // convert earth frame rates to body frame rates
        roll_rate_target_bf 	= roll_rate_target_ef - sin_pitch * yaw_rate_target_ef;
        pitch_rate_target_bf 	= cos_roll_x  * pitch_rate_target_ef + sin_roll * cos_pitch_x * yaw_rate_target_ef;
        yaw_rate_target_bf 		= cos_pitch_x * cos_roll_x * yaw_rate_target_ef - sin_roll * pitch_rate_target_ef;
    }
}


#if FRAME_CONFIG == HELI_FRAME
// init_rate_controllers - set-up filters for rate controller inputs
void init_rate_controllers()
{
   // initalise low pass filters on rate controller inputs
   // 1st parameter is time_step, 2nd parameter is time_constant
   rate_roll_filter.set_time_constant(0.01, 1.0);
   rate_pitch_filter.set_time_constant(0.01, 1.0);
   rate_yaw_filter.set_time_constant(0.01, 1.0);
   // other option for initialisation is rate_roll_filter.set_cutoff_frequency(<time_step>,<cutoff_freq>);
}
#endif // HELI_FRAME


// run roll, pitch and yaw rate controllers and send output to motors
// targets for these controllers comes from stabilize controllers
void
run_rate_controllers()
{
#if FRAME_CONFIG == HELI_FRAME          // helicopters only use rate controllers for yaw and only when not using an external gyro
    if(!motors.ext_gyro_enabled) {
		g.rc_1.servo_out = get_heli_rate_roll(roll_rate_target_bf);
		g.rc_2.servo_out = get_heli_rate_pitch(pitch_rate_target_bf);
        g.rc_4.servo_out = get_heli_rate_yaw(yaw_rate_target_bf);
    }
#else
    // call rate controllers
    g.rc_1.servo_out = get_rate_roll(roll_rate_target_bf);
    g.rc_2.servo_out = get_rate_pitch(pitch_rate_target_bf);
    g.rc_4.servo_out = get_rate_yaw(yaw_rate_target_bf);
#endif
}

#if FRAME_CONFIG == HELI_FRAME
static int16_t
get_heli_rate_roll(int32_t target_rate)
{
    int32_t p,i,d;                  // used to capture pid values for logging
	int32_t current_rate;			// this iteration's rate
    int32_t rate_error;             // simply target_rate - current_rate
    int32_t output;                 // output from pid controller

	// get current rate
	current_rate    = (omega.x * DEGX100);

    // filter input
    current_rate = rate_roll_filter.apply(current_rate);
	
    // call pid controller
    rate_error  = target_rate - (omega.x * DEGX100);
    p   = g.pid_rate_roll.get_p(rate_error);

    if (motors.flybar_mode == 1) {												// Mechanical Flybars get regular integral for rate auto trim
		if (target_rate > -50 && target_rate < 50){								// Frozen at high rates
			i		= g.pid_rate_roll.get_i(rate_error, G_Dt);
		} else {
			i		= g.pid_rate_roll.get_integrator();
		}
	} else {
		i			= g.pid_rate_roll.get_leaky_i(rate_error, G_Dt, RATE_INTEGRATOR_LEAK_RATE);		// Flybarless Helis get huge I-terms. I-term controls much of the rate
	}
	
	//d = g.pid_rate_roll.kD()*target_rate;
	d = g.pid_rate_roll.get_d(rate_error, G_Dt);

    output = p + i + d;

    // constrain output
    output = constrain(output, -4500, 4500);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0; // used to slow down logging of PID values to dataflash

    // log output if PID logging is on and we are tuning the rate P, I or D gains
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_RATE_KP || g.radio_tuning == CH6_RATE_KI || g.radio_tuning == CH6_RATE_KD) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_RATE_KP, rate_error, p, i, d, output, tuning_value);
        }
    }
#endif

    // output control
    return output;
}

static int16_t
get_heli_rate_pitch(int32_t target_rate)
{
    int32_t p,i,d;                                                                      // used to capture pid values for logging
	int32_t current_rate;                                                     			// this iteration's rate
    int32_t rate_error;                                                                 // simply target_rate - current_rate
    int32_t output;                                                                     // output from pid controller

	// get current rate
	current_rate    = (omega.y * DEGX100);
	
	// filter input
	current_rate = rate_pitch_filter.apply(current_rate);
	
	// call pid controller
    rate_error      = target_rate - (omega.y * DEGX100);
    p               = g.pid_rate_pitch.get_p(rate_error);						// Helicopters get huge feed-forward
	
	if (motors.flybar_mode == 1) {												// Mechanical Flybars get regular integral for rate auto trim
		if (target_rate > -50 && target_rate < 50){								// Frozen at high rates
			i		= g.pid_rate_pitch.get_i(rate_error, G_Dt);
		} else {
			i		= g.pid_rate_pitch.get_integrator();
		}
	} else {
		i			= g.pid_rate_pitch.get_leaky_i(rate_error, G_Dt, RATE_INTEGRATOR_LEAK_RATE);	// Flybarless Helis get huge I-terms. I-term controls much of the rate
	}
	
	//d = g.pid_rate_pitch.kD()*target_rate;
	d = g.pid_rate_pitch.get_d(rate_error, G_Dt);
    
    output = p + i + d;

    // constrain output
    output = constrain(output, -4500, 4500);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;                                      // used to slow down logging of PID values to dataflash
    // log output if PID logging is on and we are tuning the rate P, I or D gains
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_RATE_KP || g.radio_tuning == CH6_RATE_KI || g.radio_tuning == CH6_RATE_KD) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_RATE_KP+100, rate_error, p, i, 0, output, tuning_value);
        }
    }
#endif

    // output control
    return output;
}

static int16_t
get_heli_rate_yaw(int32_t target_rate)
{
    int32_t p,i,d;                                                                      // used to capture pid values for logging
	int32_t current_rate;                                                               // this iteration's rate
    int32_t rate_error;
    int32_t output;

	// get current rate
    current_rate    = (omega.z * DEGX100);
	
	// filter input
	// current_rate = rate_yaw_filter.apply(current_rate);
	
    // rate control
    rate_error              = target_rate - current_rate;

    // separately calculate p, i, d values for logging
    p = g.pid_rate_yaw.get_p(rate_error);
    
    i = g.pid_rate_yaw.get_i(rate_error, G_Dt);

    d = g.pid_rate_yaw.get_d(rate_error, G_Dt);

    output  = p+i+d;
    output = constrain(output, -4500, 4500);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;                                      // used to slow down logging of PID values to dataflash
    // log output if PID loggins is on and we are tuning the yaw
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_YAW_KP || g.radio_tuning == CH6_YAW_RATE_KP) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_YAW_RATE_KP, rate_error, p, i, d, output, tuning_value);
        }
    }
	
#endif

	// output control
	return output;
}
#endif // HELI_FRAME

#if FRAME_CONFIG != HELI_FRAME
static int16_t
get_rate_roll(int32_t target_rate)
{
    int32_t p,i,d;                  // used to capture pid values for logging
    int32_t current_rate;           // this iteration's rate
    int32_t rate_error;             // simply target_rate - current_rate
    int32_t output;                 // output from pid controller

    // get current rate
    current_rate    = (omega.x * DEGX100);

    // call pid controller
    rate_error  = target_rate - current_rate;
    p           = g.pid_rate_roll.get_p(rate_error);

    // freeze I term if we've breached roll-pitch limits
    if( motors.reached_limit(AP_MOTOR_ROLLPITCH_LIMIT) ) {
        i	= g.pid_rate_roll.get_integrator();
    }else{
        i   = g.pid_rate_roll.get_i(rate_error, G_Dt);
    }

    d = g.pid_rate_roll.get_d(rate_error, G_Dt);
    output = p + i + d;

    // constrain output
    output = constrain(output, -5000, 5000);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0; // used to slow down logging of PID values to dataflash

    // log output if PID logging is on and we are tuning the rate P, I or D gains
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_RATE_KP || g.radio_tuning == CH6_RATE_KI || g.radio_tuning == CH6_RATE_KD) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_RATE_KP, rate_error, p, i, d /*-rate_d_dampener*/, output, tuning_value);
        }
    }
#endif

    // output control
    return output;
}

static int16_t
get_rate_pitch(int32_t target_rate)
{
    int32_t p,i,d;                                                                      // used to capture pid values for logging
    int32_t current_rate;                                                       // this iteration's rate
    int32_t rate_error;                                                                 // simply target_rate - current_rate
    int32_t output;                                                                     // output from pid controller

    // get current rate
    current_rate    = (omega.y * DEGX100);

    // call pid controller
    rate_error      = target_rate - current_rate;
    p               = g.pid_rate_pitch.get_p(rate_error);
    // freeze I term if we've breached roll-pitch limits
    if( motors.reached_limit(AP_MOTOR_ROLLPITCH_LIMIT) ) {
        i = g.pid_rate_pitch.get_integrator();
    }else{
        i = g.pid_rate_pitch.get_i(rate_error, G_Dt);
    }
    d = g.pid_rate_pitch.get_d(rate_error, G_Dt);
    output = p + i + d;

    // constrain output
    output = constrain(output, -5000, 5000);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;                                      // used to slow down logging of PID values to dataflash
    // log output if PID logging is on and we are tuning the rate P, I or D gains
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_RATE_KP || g.radio_tuning == CH6_RATE_KI || g.radio_tuning == CH6_RATE_KD) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_RATE_KP+100, rate_error, p, i, d/*-rate_d_dampener*/, output, tuning_value);
        }
    }
#endif

    // output control
    return output;
}

static int16_t
get_rate_yaw(int32_t target_rate)
{
    int32_t p,i,d;                                                                      // used to capture pid values for logging
    int32_t rate_error;
    int32_t output;

    // rate control
    rate_error              = target_rate - (omega.z * DEGX100);

    // separately calculate p, i, d values for logging
    p = g.pid_rate_yaw.get_p(rate_error);
    // freeze I term if we've breached yaw limits
    if( motors.reached_limit(AP_MOTOR_YAW_LIMIT) ) {
        i = g.pid_rate_yaw.get_integrator();
    }else{
        i = g.pid_rate_yaw.get_i(rate_error, G_Dt);
    }
    d = g.pid_rate_yaw.get_d(rate_error, G_Dt);

    output  = p+i+d;
    output = constrain(output, -4500, 4500);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;                                      // used to slow down logging of PID values to dataflash
    // log output if PID loggins is on and we are tuning the yaw
    if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_YAW_KP || g.radio_tuning == CH6_YAW_RATE_KP) ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (100hz / 10hz) = 10
            log_counter = 0;
            Log_Write_PID(CH6_YAW_RATE_KP, rate_error, p, i, d, output, tuning_value);
        }
    }
#endif

#if FRAME_CONFIG == TRI_FRAME
    // constrain output
    return output;
#else // !TRI_FRAME
    // output control:
    int16_t yaw_limit = 2200 + abs(g.rc_4.control_in);

    // smoother Yaw control:
    return constrain(output, -yaw_limit, yaw_limit);
#endif // TRI_FRAME
}
#endif // !HELI_FRAME

static int16_t
get_throttle_rate(int16_t z_target_speed)
{
    int32_t p,i,d;      // used to capture pid values for logging
    int16_t z_rate_error, output = 0;

    // calculate rate error
#if INERTIAL_NAV == ENABLED
    z_rate_error    = z_target_speed - inertial_nav._velocity.z;    // calc the speed error
#else
    z_rate_error    = z_target_speed - climb_rate;              // calc the speed error
#endif

////////////////////////////////////////////////////////////////////////////////////////
// Commenting this out because 'tmp' is not being used anymore?
// Robert Lefebvre 21/11/2012
//	int16_t tmp     = ((int32_t)z_target_speed * (int32_t)g.throttle_cruise) / 280;
//	tmp 			= min(tmp, 500);

    // separately calculate p, i, d values for logging
    p = g.pid_throttle.get_p(z_rate_error);

    // freeze I term if we've breached throttle limits
    if(motors.reached_limit(AP_MOTOR_THROTTLE_LIMIT)) {
        i = g.pid_throttle.get_integrator();
    }else{
        i = g.pid_throttle.get_i(z_rate_error, .02);
    }
    d = g.pid_throttle.get_d(z_rate_error, .02);

    //
    // limit the rate
    output +=  constrain(p+i+d, THROTTLE_RATE_CONSTRAIN_NEGATIVE, THROTTLE_RATE_CONSTRAIN_POSITIVE);

#if LOGGING_ENABLED == ENABLED
    static int8_t log_counter = 0;                                      // used to slow down logging of PID values to dataflash
    // log output if PID loggins is on and we are tuning the yaw
    if( g.log_bitmask & MASK_LOG_PID && g.radio_tuning == CH6_THROTTLE_KP ) {
        log_counter++;
        if( log_counter >= 10 ) {               // (update rate / desired output rate) = (50hz / 10hz) = 5hz
            log_counter = 0;
            Log_Write_PID(CH6_THROTTLE_KP, z_rate_error, p, i, d, output, tuning_value);
        }
    }
#endif

    return output;
}

// Keeps old data out of our calculation / logs
static void reset_nav_params(void)
{
    nav_throttle                    = 0;

    // always start Circle mode at same angle
    circle_angle                    = 0;

    // We must be heading to a new WP, so XTrack must be 0
    crosstrack_error                = 0;

    // Will be set by new command
    target_bearing                  = 0;

    // Will be set by new command
    wp_distance                     = 0;

    // Will be set by new command, used by loiter
    long_error                      = 0;
    lat_error                       = 0;
    nav_lon 						= 0;
    nav_lat 						= 0;
    nav_roll 						= 0;
    nav_pitch 						= 0;
    auto_roll 						= 0;
    auto_pitch 						= 0;

    // make sure we stick to Nav yaw on takeoff
    auto_yaw = nav_yaw;
}

/*
 *  reset all I integrators
 */
static void reset_I_all(void)
{
    reset_rate_I();
    reset_stability_I();
    reset_wind_I();
    reset_throttle_I();
    reset_optflow_I();

    // This is the only place we reset Yaw
    g.pi_stabilize_yaw.reset_I();
}

static void reset_rate_I()
{
    g.pid_rate_roll.reset_I();
    g.pid_rate_pitch.reset_I();
    g.pid_rate_yaw.reset_I();
}

static void reset_optflow_I(void)
{
    g.pid_optflow_roll.reset_I();
    g.pid_optflow_pitch.reset_I();
    of_roll = 0;
    of_pitch = 0;
}

static void reset_wind_I(void)
{
    // Wind Compensation
    // this i is not currently being used, but we reset it anyway
    // because someone may modify it and not realize it, causing a bug
    g.pi_loiter_lat.reset_I();
    g.pi_loiter_lon.reset_I();

    g.pid_loiter_rate_lat.reset_I();
    g.pid_loiter_rate_lon.reset_I();

    g.pid_nav_lat.reset_I();
    g.pid_nav_lon.reset_I();
}

static void reset_throttle_I(void)
{
    // For Altitude Hold
    g.pi_alt_hold.reset_I();
    g.pid_throttle.reset_I();
}

static void reset_stability_I(void)
{
    // Used to balance a quad
    // This only needs to be reset during Auto-leveling in flight
    g.pi_stabilize_roll.reset_I();
    g.pi_stabilize_pitch.reset_I();
}


/*************************************************************
 *  throttle control
 ****************************************************************/

static int16_t get_angle_boost(int16_t value)
{
    float temp = cos_pitch_x * cos_roll_x;
    temp = constrain(temp, .75, 1.0);
    return ((float)(value + 80) / temp) - (value + 80);
}

// calculate modified roll/pitch depending upon optical flow calculated position
static int32_t
get_of_roll(int32_t input_roll)
{
#if OPTFLOW == ENABLED
    static float tot_x_cm = 0;      // total distance from target
    static uint32_t last_of_roll_update = 0;
    int32_t new_roll = 0;
    int32_t p,i,d;

    // check if new optflow data available
    if( optflow.last_update != last_of_roll_update) {
        last_of_roll_update = optflow.last_update;

        // add new distance moved
        tot_x_cm += optflow.x_cm;

        // only stop roll if caller isn't modifying roll
        if( input_roll == 0 && current_loc.alt < 1500) {
            p = g.pid_optflow_roll.get_p(-tot_x_cm);
            i = g.pid_optflow_roll.get_i(-tot_x_cm,1.0);              // we could use the last update time to calculate the time change
            d = g.pid_optflow_roll.get_d(-tot_x_cm,1.0);
            new_roll = p+i+d;
        }else{
            g.pid_optflow_roll.reset_I();
            tot_x_cm = 0;
            p = 0;              // for logging
            i = 0;
            d = 0;
        }
        // limit amount of change and maximum angle
        of_roll = constrain(new_roll, (of_roll-20), (of_roll+20));

 #if LOGGING_ENABLED == ENABLED
        static int8_t log_counter = 0;                                  // used to slow down logging of PID values to dataflash
        // log output if PID logging is on and we are tuning the rate P, I or D gains
        if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_OPTFLOW_KP || g.radio_tuning == CH6_OPTFLOW_KI || g.radio_tuning == CH6_OPTFLOW_KD) ) {
            log_counter++;
            if( log_counter >= 5 ) {                    // (update rate / desired output rate) = (100hz / 10hz) = 10
                log_counter = 0;
                Log_Write_PID(CH6_OPTFLOW_KP, tot_x_cm, p, i, d, of_roll, tuning_value);
            }
        }
 #endif // LOGGING_ENABLED == ENABLED
    }

    // limit max angle
    of_roll = constrain(of_roll, -1000, 1000);

    return input_roll+of_roll;
#else
    return input_roll;
#endif  // OPTFLOW == ENABLED
}

static int32_t
get_of_pitch(int32_t input_pitch)
{
#if OPTFLOW == ENABLED
    static float tot_y_cm = 0;  // total distance from target
    static uint32_t last_of_pitch_update = 0;
    int32_t new_pitch = 0;
    int32_t p,i,d;

    // check if new optflow data available
    if( optflow.last_update != last_of_pitch_update ) {
        last_of_pitch_update = optflow.last_update;

        // add new distance moved
        tot_y_cm += optflow.y_cm;

        // only stop roll if caller isn't modifying pitch
        if( input_pitch == 0 && current_loc.alt < 1500 ) {
            p = g.pid_optflow_pitch.get_p(tot_y_cm);
            i = g.pid_optflow_pitch.get_i(tot_y_cm, 1.0);              // we could use the last update time to calculate the time change
            d = g.pid_optflow_pitch.get_d(tot_y_cm, 1.0);
            new_pitch = p + i + d;
        }else{
            tot_y_cm = 0;
            g.pid_optflow_pitch.reset_I();
            p = 0;              // for logging
            i = 0;
            d = 0;
        }

        // limit amount of change
        of_pitch = constrain(new_pitch, (of_pitch-20), (of_pitch+20));

 #if LOGGING_ENABLED == ENABLED
        static int8_t log_counter = 0;                                  // used to slow down logging of PID values to dataflash
        // log output if PID logging is on and we are tuning the rate P, I or D gains
        if( g.log_bitmask & MASK_LOG_PID && (g.radio_tuning == CH6_OPTFLOW_KP || g.radio_tuning == CH6_OPTFLOW_KI || g.radio_tuning == CH6_OPTFLOW_KD) ) {
            log_counter++;
            if( log_counter >= 5 ) {                    // (update rate / desired output rate) = (100hz / 10hz) = 10
                log_counter = 0;
                Log_Write_PID(CH6_OPTFLOW_KP+100, tot_y_cm, p, i, d, of_pitch, tuning_value);
            }
        }
 #endif // LOGGING_ENABLED == ENABLED
    }

    // limit max angle
    of_pitch = constrain(of_pitch, -1000, 1000);

    return input_pitch+of_pitch;
#else
    return input_pitch;
#endif  // OPTFLOW == ENABLED
}
