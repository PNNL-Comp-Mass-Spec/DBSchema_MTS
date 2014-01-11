/****** Object:  Database [MT_Main] ******/
CREATE DATABASE [MT_Main] ON  PRIMARY 
( NAME = N'MT_Main_Data', FILENAME = N'I:\SQLServerData\MT_Main_data.mdf' , SIZE = 2044864KB , MAXSIZE = UNLIMITED, FILEGROWTH = 80KB )
 LOG ON 
( NAME = N'MT_Main_Log', FILENAME = N'H:\SQLServerData\MT_Main_log.ldf' , SIZE = 149056KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
ALTER DATABASE [MT_Main] SET COMPATIBILITY_LEVEL = 100
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [MT_Main].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [MT_Main] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [MT_Main] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [MT_Main] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [MT_Main] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [MT_Main] SET ARITHABORT OFF 
GO
ALTER DATABASE [MT_Main] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [MT_Main] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [MT_Main] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [MT_Main] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [MT_Main] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [MT_Main] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [MT_Main] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [MT_Main] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [MT_Main] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [MT_Main] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [MT_Main] SET  DISABLE_BROKER 
GO
ALTER DATABASE [MT_Main] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [MT_Main] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [MT_Main] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [MT_Main] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [MT_Main] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [MT_Main] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [MT_Main] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [MT_Main] SET  READ_WRITE 
GO
ALTER DATABASE [MT_Main] SET RECOVERY FULL 
GO
ALTER DATABASE [MT_Main] SET  MULTI_USER 
GO
ALTER DATABASE [MT_Main] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [MT_Main] SET DB_CHAINING OFF 
GO
GRANT CONNECT TO [d3m578] AS [dbo]
GO
GRANT CONNECT TO [dmswebuser] AS [dbo]
GO
GRANT CONNECT TO [h0693075] AS [dbo]
GO
GRANT CONNECT TO [msdadmin] AS [dbo]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
GRANT SHOWPLAN TO [MTUser] AS [dbo]
GO
GRANT CONNECT TO [pnl\d3m651] AS [dbo]
GO
