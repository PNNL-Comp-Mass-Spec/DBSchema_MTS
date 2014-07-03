/****** Object:  Table [dbo].[T_Peak_Matching_NET_Value_Type_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_NET_Value_Type_Name](
	[NET_Value_Type] [tinyint] NOT NULL,
	[NET_Value_Type_Name] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Peak_Matching_NET_Value_Type_Name] PRIMARY KEY CLUSTERED 
(
	[NET_Value_Type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
