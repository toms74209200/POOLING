-- =====================================================================
--  Title       : Max pooling
--
--  File Name   : Pooling.vhd
--  Project     : 
--  Block       :
--  Tree        :
--  Designer    : toms74209200 <https://github.com/toms74209200>
--  Created     : 2019/08/17
--  Copyright   : 2019 toms74209200
--  License     : MIT License.
--                http://opensource.org/licenses/mit-license.php
-- =====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity POOLING is
    generic(
        W           : integer := 5;                            -- Image data width
        H           : integer := 5                             -- Image data height
    );
    port(
    -- System --
        nRST        : in    std_logic;                          --(n) Reset
        CLK         : in    std_logic;                          --(p) Clock

    -- Control --
        WR          : in    std_logic;                          --(p) Raw data input enable
        RD          : out   std_logic;                          --(p) Convolution data output timing
        WDAT        : in    std_logic_vector(7 downto 0);       --(p) Raw data
        RDAT        : out   std_logic_vector(7 downto 0)        --(p) Convolution data

        );
end POOLING;

architecture RTL of POOLING is

-- Internal signal --
-- Write sequence --
signal wp_cnt           : integer range 0 to 2;                 --(p) Line buffer control pointer
signal wh_cnt           : integer range 0 to 2**H-1;            --(p) Raw image row bit count
signal ww_cnt           : integer range 0 to 2**W;              --(p) Raw image column bit count

-- Read sequence --
signal busy             : std_logic;                            --(p) Pooling busy flag
signal rp_cnt           : integer range 0 to 2;                 --(p) Line buffer control pointer
signal rh_cnt           : std_logic_vector(H downto 0);         --(p) Pooling image row bit count
signal rw_cnt           : std_logic_vector(W downto 0);         --(p) Pooling image column bit count
signal rwo_cnt          : std_logic_vector(W-1 downto 0);       --(p) Pooling image column bit output count
signal cell_cnt         : integer range 0 to 2;                 --(p) Pooling cell column bit count
signal rwo_ena          : std_logic;                            --(p) Pooling data output assert
signal rd_i             : std_logic;                            --(p) Pooling data output assert
signal rd_ii            : std_logic;                            --(p) Pooling data output assert
signal cmp_1            : std_logic_vector(WDAT'range);         --(p) Compilation data
signal cmp_2            : std_logic_vector(WDAT'range);         --(p) Compilation data
signal rdat_i           : std_logic_vector(WDAT'range);         --(p) Pooling data

-- Line buffer(2**W length / 8bit color) --
type LBF_TYP            is array (0 to 2**W-1) of std_logic_vector(7 downto 0);
signal lbf0             : LBF_TYP;                              --(p) Line buffer
signal lbf1             : LBF_TYP;                              --(p) Line buffer
signal lbf2             : LBF_TYP;                              --(p) Line buffer

-- Compilation cell --
type CMP_TYP            is array (0 to 1, 0 to 1) of std_logic_vector(7 downto 0);
signal cmp_cell         : CMP_TYP;                              --(p) Compilation cell

begin
--
-- ***********************************************************
--  Line buffer control pointer
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        wp_cnt <= 0;
    elsif (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (ww_cnt = 2**W-1) then
                if (wh_cnt = 2**H-1) then
                    wp_cnt <= wp_cnt;
                else
                    if (wp_cnt = 2) then
                        wp_cnt <= 0;
                    else
                        wp_cnt <= wp_cnt + 1;
                    end if;
                end if;
            end if;
        elsif (busy = '1') then
            if (wh_cnt = 2**H-1 and rh_cnt = 2**H-1 and rw_cnt = 2**W-1) then
                wp_cnt <= 0;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Raw image row bit count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        wh_cnt <= 0;
    elsif (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (ww_cnt = 2**W-1) then
                if (wh_cnt = 2**H-1) then
                    wh_cnt <= wh_cnt;
                else
                    wh_cnt <= wh_cnt + 1;
                end if;
            end if;
        elsif (busy = '1') then
            if (wh_cnt = 2**H-1 and rh_cnt = 2**(H-1)-1 and rw_cnt = 2**(W-1)-1) then
                wh_cnt <= 0;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Raw image column bit count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        ww_cnt <= 0;
    elsif (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (wh_cnt = 2**H-1) then
                if (ww_cnt = 2**W-1) then
                    ww_cnt <= ww_cnt;
                else
                    ww_cnt <= ww_cnt + 1;
                end if;
            else
                if (ww_cnt = 2**W-1) then
                    ww_cnt <= 0;
                else
                    ww_cnt <= ww_cnt + 1;
                end if;
            end if;
        elsif (busy = '1') then
            if (wh_cnt = 2**H-1 and rh_cnt = 2**(H-1)-1 and rw_cnt = 2**(W-1)-1) then
                ww_cnt <= 0;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Line buffer
-- ***********************************************************
process (CLK) begin
    if (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (wp_cnt = 0) then
                lbf0(ww_cnt) <= WDAT;
            end if;
        end if;
    end if;
end process;

process (CLK) begin
    if (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (wp_cnt = 1) then
                lbf1(ww_cnt) <= WDAT;
            end if;
        end if;
    end if;
end process;

process (CLK) begin
    if (CLK'event and CLK = '1') then
        if (WR = '1') then
            if (wp_cnt = 2) then
                lbf2(ww_cnt) <= WDAT;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Convolution busy flag
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        busy <= '0';
    elsif (CLK'event and CLK = '1') then
        if (rh_cnt = 2**(H-1)-1 and rwo_cnt = 2**(W-1)) then
            busy <= '0';
        elsif (wh_cnt = 2**H-1 and ww_cnt = 2**W-1) then
            busy <= '1';
        elsif (wh_cnt = 0) then
            busy <= '0';
        elsif (wh_cnt-1 > CONV_INTEGER(rh_cnt)*2) then
            busy <= '1';
        else
            busy <= '0';
        end if;
    end if;
end process;


-- ***********************************************************
--  Line buffer control pointer
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        rp_cnt <= 0;
    elsif (CLK'event and CLK = '1') then
        if (rh_cnt = 2**(H-1)-1 and rwo_cnt = 2**(W-1)) then
            rp_cnt <= 0;
        elsif (rd_i = '1') then
            if (rwo_cnt = 2**(W-1)) then
                if (rp_cnt = 1) then
                    rp_cnt <= 0;
                else
                    rp_cnt <= rp_cnt + 1;
                end if;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Raw image row bit count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        rh_cnt <= (others => '0');
    elsif (CLK'event and CLK = '1') then
        if (rd_i = '1' and rwo_cnt = 2**(W-1)-1) then
            if (rh_cnt = 2**(H-1)-1) then
                rh_cnt <= (others => '0');
            else
                rh_cnt <= rh_cnt + 1;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Raw image column bit count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        rw_cnt <= (others => '0');
    elsif (CLK'event and CLK = '1') then
        if (busy = '1') then
            if (rw_cnt = 2**W-1) then
                rw_cnt <= rw_cnt;
            else
                rw_cnt <= rw_cnt + 1;
            end if;
        else
            rw_cnt <= (others => '0');
        end if;
    end if;
end process;


-- ***********************************************************
--  Convolution cell column bit count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        cell_cnt <= 0;
    elsif (CLK'event and CLK = '1') then
        if (busy = '1') then
            if (cell_cnt = 2) then
                cell_cnt <= 0;
            else
                cell_cnt <= cell_cnt + 1;
            end if;
        else
            cell_cnt <= 0;
        end if;
    end if;
end process;


-- ***********************************************************
--  Convolution cell register
-- ***********************************************************
process (CLK) begin
    if (CLK'event and CLK = '1') then
        if (busy = '1' or rd_i = '1') then
            case (rp_cnt) is
                when 0 =>
                    cmp_cell(0, cell_cnt) <= lbf0(CONV_INTEGER(rw_cnt));
                    cmp_cell(1, cell_cnt) <= lbf1(CONV_INTEGER(rw_cnt));
                when 1 =>
                    cmp_cell(0, cell_cnt) <= lbf2(CONV_INTEGER(rw_cnt));
                    cmp_cell(1, cell_cnt) <= lbf0(CONV_INTEGER(rw_cnt));
                when others =>
                    cmp_cell(0, cell_cnt) <= cmp_cell(0, cell_cnt);
                    cmp_cell(1, cell_cnt) <= cmp_cell(1, cell_cnt);
            end case;
        else
            cmp_cell(0, cell_cnt) <= (others => '0');
            cmp_cell(1, cell_cnt) <= (others => '0');
        end if;
    end if;
end process;


-- ***********************************************************
--  Max pooling compilation
-- ***********************************************************
cmp_1 <= cmp_cell(0, cell_cnt) when (cmp_cell(0, cell_cnt) > cmp_cell(0, cell_cnt+1)) else
         cmp_cell(0, cell_cnt+1);
cmp_2 <= cmp_cell(1, cell_cnt) when (cmp_cell(1, cell_cnt) > cmp_cell(1, cell_cnt+1)) else
         cmp_cell(1, cell_cnt+1);

process (CLK, nRST) begin
    if (nRST = '0') then
        rdat_i <= (others => '0');
    elsif (CLK'event and CLK = '1') then
        if (rd_i = '1') then
            if (cmp_1 > cmp_2) then
                rdat_i <= cmp_1;
            else
                rdat_i <= cmp_2;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Pooling image column bit output count
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        rwo_cnt <= (others => '0');
    elsif (CLK'event and CLK = '1') then
        if (rd_i = '1') then
            if (rwo_cnt = 2**(W-1)) then
                rwo_cnt <= (others => '0');
            else
                rwo_cnt <= rwo_cnt + 1;
            end if;
        end if;
    end if;
end process;


-- ***********************************************************
--  Output assert
-- ***********************************************************
process (CLK, nRST) begin
    if (nRST = '0') then
        rd_i <= '0';
    elsif (CLK'event and CLK = '1') then
        if (busy = '1') then
            if (rw_cnt < 1 and rwo_cnt = 0) then
                rd_i <= '0';
            else
                rd_i <= not rd_i;
            end if;
        else
            rd_i <= '0';
        end if;
    end if;
end process;

process (CLK, nRST) begin
    if (nRST = '0') then
        rd_ii <= '0';
    elsif (CLK'event and CLK = '1') then
        if (busy = '1') then
            rd_ii <= rd_i;
        else
            rd_ii <= '0';
        end if;
    end if;
end process;


-- ***********************************************************
--  Output data
-- ***********************************************************
RD <= rd_ii;
RDAT <= rdat_i;


end RTL;    -- POOLING