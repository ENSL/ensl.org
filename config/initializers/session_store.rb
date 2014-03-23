Ensl::Application.config.session_store :active_record_store,
                                       :key => '_ENSL_session_key',
                                       :expire_after => 30.days.to_i
                                       