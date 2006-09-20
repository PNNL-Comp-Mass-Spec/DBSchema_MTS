/****** Object:  Table [dbo].[T_Event_Target] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Event_Target](
	[ID] [int] NOT NULL,
	[Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Target_Table] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Target_ID_Column] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Target_State_Column] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Event_Target] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
