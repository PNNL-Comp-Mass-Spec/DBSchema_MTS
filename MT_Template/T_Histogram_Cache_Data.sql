/****** Object:  Table [dbo].[T_Histogram_Cache_Data] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Histogram_Cache_Data](
	[Histogram_Cache_ID] [int] NOT NULL,
	[Bin] [float] NOT NULL,
	[Frequency] [int] NOT NULL,
 CONSTRAINT [PK_T_Histogram_Cache_Data] PRIMARY KEY CLUSTERED 
(
	[Histogram_Cache_ID] ASC,
	[Bin] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Histogram_Cache_Data]  WITH CHECK ADD  CONSTRAINT [FK_T_Histogram_Cache_Data_T_Histogram_Cache] FOREIGN KEY([Histogram_Cache_ID])
REFERENCES [T_Histogram_Cache] ([Histogram_Cache_ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[T_Histogram_Cache_Data] CHECK CONSTRAINT [FK_T_Histogram_Cache_Data_T_Histogram_Cache]
GO
