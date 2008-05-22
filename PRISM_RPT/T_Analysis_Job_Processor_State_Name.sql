/****** Object:  Table [dbo].[T_Analysis_Job_Processor_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job_Processor_State_Name](
	[State] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[State_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Analysis_Job_Processor_State_Name] PRIMARY KEY CLUSTERED 
(
	[State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
