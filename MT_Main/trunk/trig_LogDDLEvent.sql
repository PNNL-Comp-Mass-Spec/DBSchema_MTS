/****** Object:  Trigger [dbo].[trig_LogDDLEvent] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[trig_LogDDLEvent] ON DATABASE 
    FOR DDL_DATABASE_LEVEL_EVENTS 
AS 
    DECLARE @data XML 
    SET @data = EVENTDATA() 
    IF @data.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(256)') 
        <> 'CREATE_STATISTICS'  
        INSERT  INTO T_DDL_Change_Log 
                ( 
                  Event_Type, 
                  Object, 
                  Object_Type, 
                  tsql 
                ) 
        VALUES  ( 
                   @data.value('(/EVENT_INSTANCE/EventType)[1]', 
                              'nvarchar(256)'), 
                  @data.value('(/EVENT_INSTANCE/ObjectName)[1]', 
                              'nvarchar(256)'), 
                  @data.value('(/EVENT_INSTANCE/ObjectType)[1]', 
                              'nvarchar(256)'), 
                  @data.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 
                              'nvarchar(max)') 
                ) ; 
GO 

ENABLE TRIGGER [dbo].[trig_LogDDLEvent] ON DATABASE