/****** Object:  Database [Master_Sequences] ******/
CREATE DATABASE [Master_Sequences]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Master_Sequences_Data', FILENAME = N'J:\SQLServerData\Master_Sequences_Data.mdf' , SIZE = 177676032KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'Master_Sequences_Log', FILENAME = N'L:\SQLServerData\Master_Sequences_Log.ldf' , SIZE = 127117504KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [Master_Sequences].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [Master_Sequences] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [Master_Sequences] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [Master_Sequences] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [Master_Sequences] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [Master_Sequences] SET ARITHABORT OFF 
GO
ALTER DATABASE [Master_Sequences] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [Master_Sequences] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [Master_Sequences] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [Master_Sequences] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [Master_Sequences] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [Master_Sequences] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [Master_Sequences] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [Master_Sequences] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [Master_Sequences] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [Master_Sequences] SET  DISABLE_BROKER 
GO
ALTER DATABASE [Master_Sequences] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [Master_Sequences] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [Master_Sequences] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [Master_Sequences] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [Master_Sequences] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [Master_Sequences] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [Master_Sequences] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [Master_Sequences] SET RECOVERY FULL 
GO
ALTER DATABASE [Master_Sequences] SET  MULTI_USER 
GO
ALTER DATABASE [Master_Sequences] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [Master_Sequences] SET DB_CHAINING OFF 
GO
ALTER DATABASE [Master_Sequences] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [Master_Sequences] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [Master_Sequences] SET DELAYED_DURABILITY = DISABLED 
GO
USE [Master_Sequences]
GO
/****** Object:  User [MTAdmin] ******/
CREATE USER [MTAdmin] FOR LOGIN [mtadmin] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [MTS_DB_Dev] ******/
CREATE USER [MTS_DB_Dev] FOR LOGIN [Pogo\MTS_DB_Dev]
GO
/****** Object:  User [MTS_DB_Lite] ******/
CREATE USER [MTS_DB_Lite] FOR LOGIN [Pogo\MTS_DB_Lite]
GO
/****** Object:  User [MTS_DB_Reader] ******/
CREATE USER [MTS_DB_Reader] FOR LOGIN [Pogo\MTS_DB_Reader]
GO
/****** Object:  User [MTUser] ******/
CREATE USER [MTUser] FOR LOGIN [mtuser] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [PNL\D3M578] ******/
CREATE USER [PNL\D3M578] FOR LOGIN [PNL\D3M578] WITH DEFAULT_SCHEMA=[PNL\D3M578]
GO
/****** Object:  User [PNL\D3M580] ******/
CREATE USER [PNL\D3M580] FOR LOGIN [PNL\D3M580] WITH DEFAULT_SCHEMA=[PNL\D3M580]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
ALTER DATABASE [Master_Sequences] SET  READ_WRITE 
GO
